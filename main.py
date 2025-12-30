"""
Mini ATS Resume Analyzer - Backend
FastAPI server with PDF parsing and AWS Bedrock Nova Micro integration
"""

import os
import json
import re
from typing import Optional
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
import pdfplumber
import boto3
from botocore.exceptions import ClientError
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(title="Mini ATS Resume Analyzer")

# AWS Configuration
AWS_REGION = os.getenv("AWS_REGION", "ap-south-2")

# Initialize Bedrock Runtime client
try:
    bedrock_runtime = boto3.client(
        service_name='bedrock-runtime',
        region_name=AWS_REGION
    )
    print(f"✅ AWS Bedrock client initialized for region: {AWS_REGION}")
except Exception as e:
    print(f"⚠️  WARNING: Could not initialize AWS Bedrock client: {e}")
    print("   Ensure AWS credentials are configured (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)")
    bedrock_runtime = None

# Constants
MAX_RESUME_CHARS = 8000  # Cap text length to avoid token limits
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB
BEDROCK_MODEL_ID = "amazon.nova-micro-v1:0"  # Amazon Nova Micro model


# Request/Response Models
class AnalyzeRequest(BaseModel):
    resume_text: str
    job_input: str


class Tip(BaseModel):
    issue: str
    why: str
    fix: str


class AnalyzeResponse(BaseModel):
    score: int
    matched_keywords: list[str]
    missing_keywords: list[str]
    tips: list[Tip]


class ParseResponse(BaseModel):
    resume_text: str


# ATS System Prompt
ATS_SYSTEM_PROMPT = """You are a strict ATS (Applicant Tracking System) scanner. Your job is to mechanically compare resumes against job descriptions using keyword matching.

RULES:
1. Act like an ATS, NOT a career coach
2. Only identify skills/tools explicitly mentioned - NEVER invent or assume skills
3. Be strict and mechanical in your analysis
4. Focus on hard skills, tools, technologies, and frameworks
5. Weight technical keywords higher than soft skills

SCORING LOGIC (explain this in your analysis):
- 70% weight: Technical keyword match (tools, languages, frameworks, technologies)
- 20% weight: Role relevance (job title alignment, core responsibilities)
- 10% weight: Resume structure signals (presence of Skills, Projects, Experience sections)

OUTPUT FORMAT - You MUST respond with ONLY valid JSON, no other text:
{
    "score": <number 0-100>,
    "matched_keywords": ["keyword1", "keyword2"],
    "missing_keywords": ["keyword1", "keyword2"],
    "tips": [
        {
            "issue": "What specific keyword/skill is missing",
            "why": "Why ATS systems penalize this (be specific about keyword matching)",
            "fix": "Exact wording suggestion to add to resume"
        }
    ]
}

IMPORTANT:
- Generate EXACTLY 3 tips, no more, no less
- Each tip must have all three fields: issue, why, fix
- The "fix" field should contain actionable, copy-paste ready text
- matched_keywords and missing_keywords should be specific technical terms
- Score should reflect realistic ATS keyword matching, not subjective quality"""


def extract_text_from_pdf(file_content: bytes) -> str:
    """Extract text from PDF using pdfplumber, with OCR fallback for image-based PDFs"""
    import io
    
    text_parts = []
    
    # First, try pdfplumber (fast, works for text-based PDFs)
    try:
        with pdfplumber.open(io.BytesIO(file_content)) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text_parts.append(page_text)
    except Exception as e:
        print(f"pdfplumber failed: {e}")
    
    full_text = "\n".join(text_parts).strip()
    
    # If no text extracted, try OCR fallback
    if not full_text:
        print("📸 No text found with pdfplumber, trying OCR...")
        try:
            from pdf2image import convert_from_bytes
            import pytesseract
            
            # Convert PDF pages to images
            images = convert_from_bytes(file_content, dpi=200)
            
            ocr_text_parts = []
            for i, image in enumerate(images):
                print(f"   OCR processing page {i + 1}/{len(images)}...")
                page_text = pytesseract.image_to_string(image)
                if page_text.strip():
                    ocr_text_parts.append(page_text)
            
            full_text = "\n".join(ocr_text_parts).strip()
            
            if full_text:
                print(f"✅ OCR extracted {len(full_text)} characters")
            else:
                print("❌ OCR also returned no text")
                
        except ImportError as e:
            print(f"❌ OCR dependencies not available: {e}")
            print("   Install with: pip install pdf2image pytesseract")
            print("   Also install Tesseract OCR: https://github.com/tesseract-ocr/tesseract")
        except Exception as e:
            print(f"❌ OCR failed: {e}")
    
    # Clean up excessive whitespace
    full_text = re.sub(r'\n{3,}', '\n\n', full_text)
    full_text = re.sub(r' {2,}', ' ', full_text)
    
    return full_text.strip()



def truncate_text(text: str, max_chars: int = MAX_RESUME_CHARS) -> str:
    """Truncate text to avoid token limits while keeping meaningful content"""
    if len(text) <= max_chars:
        return text
    
    # Try to truncate at a sentence boundary
    truncated = text[:max_chars]
    last_period = truncated.rfind('.')
    if last_period > max_chars * 0.8:  # Only if we're not losing too much
        truncated = truncated[:last_period + 1]
    
    return truncated + "\n[... Resume truncated for processing ...]"


def parse_llm_response(response_text: str) -> dict:
    """Parse LLM response, handling potential JSON extraction issues"""
    # Try direct JSON parse first
    try:
        return json.loads(response_text)
    except json.JSONDecodeError:
        pass
    
    # Try to extract JSON from markdown code block
    json_match = re.search(r'```(?:json)?\s*([\s\S]*?)\s*```', response_text)
    if json_match:
        try:
            return json.loads(json_match.group(1))
        except json.JSONDecodeError:
            pass
    
    # Try to find JSON object in the text
    json_match = re.search(r'\{[\s\S]*\}', response_text)
    if json_match:
        try:
            return json.loads(json_match.group(0))
        except json.JSONDecodeError:
            pass
    
    raise ValueError("Could not parse LLM response as JSON")


def invoke_bedrock_nova(system_prompt: str, user_message: str) -> str:
    """Invoke AWS Bedrock Nova Micro model"""
    if not bedrock_runtime:
        raise RuntimeError("AWS Bedrock client not initialized")
    
    # Prepare the request body for Amazon Nova Micro
    # Nova models use the Messages API format
    request_body = {
        "messages": [
            {
                "role": "user",
                "content": [
                    {"text": f"{system_prompt}\n\n{user_message}"}
                ]
            }
        ],
        "inferenceConfig": {
            "maxTokens": 1024,
            "temperature": 0.1,
            "topP": 0.9
        }
    }
    
    try:
        response = bedrock_runtime.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            body=json.dumps(request_body),
            contentType="application/json",
            accept="application/json"
        )
        
        # Parse the response
        response_body = json.loads(response['body'].read())
        
        # Extract the generated text from Nova response format
        if 'output' in response_body and 'message' in response_body['output']:
            content = response_body['output']['message']['content']
            if content and len(content) > 0:
                return content[0].get('text', '')
        
        raise ValueError("Unexpected response format from Bedrock")
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        raise RuntimeError(f"Bedrock API error ({error_code}): {error_message}")


@app.post("/parse-resume", response_model=ParseResponse)
async def parse_resume(file: UploadFile = File(...)):
    """Parse uploaded PDF resume and extract text"""
    
    # Validate file type
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Only PDF files are accepted")
    
    # Read file content
    content = await file.read()
    
    # Validate file size
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="File size exceeds 5MB limit")
    
    # Extract text
    try:
        resume_text = extract_text_from_pdf(content)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to parse PDF: {str(e)}")
    
    if not resume_text.strip():
        raise HTTPException(status_code=400, detail="Your resume is not ATS Parsable. It's image based.")
    
    return ParseResponse(resume_text=resume_text)


@app.post("/analyze", response_model=AnalyzeResponse)
async def analyze_resume(request: AnalyzeRequest):
    """Analyze resume against job description using AWS Bedrock Nova Micro"""
    
    if not bedrock_runtime:
        raise HTTPException(
            status_code=500, 
            detail="AWS Bedrock not configured. Please ensure AWS credentials are set."
        )
    
    if not request.resume_text.strip():
        raise HTTPException(status_code=400, detail="Resume text is empty")
    
    if not request.job_input.strip():
        raise HTTPException(status_code=400, detail="Job input is empty")
    
    # Truncate resume text to avoid token limits
    truncated_resume = truncate_text(request.resume_text)
    
    # Prepare the user message
    user_message = f"""Analyze this resume against the job requirements.

JOB REQUIREMENTS:
{request.job_input}

RESUME:
{truncated_resume}

Respond with ONLY the JSON object as specified. No explanations or additional text."""

    try:
        # Call AWS Bedrock Nova Micro
        response_text = invoke_bedrock_nova(ATS_SYSTEM_PROMPT, user_message)
        
        # Parse the response
        result = parse_llm_response(response_text)
        
        # Validate and sanitize the response
        score = max(0, min(100, int(result.get("score", 50))))
        matched = result.get("matched_keywords", [])[:15]  # Cap at 15
        missing = result.get("missing_keywords", [])[:10]  # Cap at 10
        tips = result.get("tips", [])[:3]  # Exactly 3
        
        # Ensure tips have correct structure
        validated_tips = []
        for tip in tips:
            if isinstance(tip, dict):
                validated_tips.append(Tip(
                    issue=str(tip.get("issue", "Missing keyword")),
                    why=str(tip.get("why", "ATS filters by keywords")),
                    fix=str(tip.get("fix", "Add relevant keywords to your resume"))
                ))
        
        # Pad with default tips if needed
        while len(validated_tips) < 3:
            validated_tips.append(Tip(
                issue="Review keyword density",
                why="ATS systems rank resumes by keyword frequency",
                fix="Ensure key skills from the JD appear multiple times naturally"
            ))
        
        return AnalyzeResponse(
            score=score,
            matched_keywords=matched,
            missing_keywords=missing,
            tips=validated_tips[:3]
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint for AWS ALB/Lambda"""
    return {"status": "healthy", "region": AWS_REGION, "model": BEDROCK_MODEL_ID}


# Serve static files (frontend)
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/")
async def root():
    """Serve the frontend"""
    return FileResponse("static/index.html")


# Lambda handler using Mangum
try:
    from mangum import Mangum
    handler = Mangum(app)
    print("✅ Mangum Lambda handler initialized")
except ImportError:
    handler = None
    print("ℹ️  Mangum not installed - running in local mode only")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
