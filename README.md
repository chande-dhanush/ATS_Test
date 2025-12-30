# 📄 ATS Resume Analyzer

A lightweight tool that simulates how an **Applicant Tracking System (ATS)** screens your resume against job descriptions. Get clear, actionable feedback to improve your resume's ATS compatibility.

![ATS Resume Analyzer](https://img.shields.io/badge/Python-3.11+-blue) ![FastAPI](https://img.shields.io/badge/FastAPI-Backend-green) ![AWS](https://img.shields.io/badge/AWS-Bedrock-orange) ![Terraform](https://img.shields.io/badge/Terraform-IaC-purple)

---

## 🚀 Deployment Options

### Option 1: AWS Deployment (Production)

This project is configured for **serverless AWS deployment** with:
- **AWS Lambda** + **API Gateway** for the backend
- **AWS Bedrock Nova Micro** for AI analysis
- **GitHub Actions** for CI/CD
- **Terraform** for infrastructure as code

#### Prerequisites

1. **AWS Account** with:
   - Bedrock access enabled for Nova Micro model
   - IAM user with programmatic access
   
2. **GitHub Repository** with these secrets configured:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

3. **Terraform** installed locally (for initial setup)

#### Quick AWS Setup

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd ATS-Checker

# 2. Initialize Terraform
cd terraform
terraform init

# 3. Deploy infrastructure (first time only)
terraform apply -auto-approve

# 4. Push to GitHub to trigger CI/CD
git add .
git commit -m "Initial deployment"
git push origin main
```

After deployment, your API will be available at the URL shown in Terraform outputs.

#### GitHub Actions CI/CD

The pipeline automatically:
1. ✅ Builds Docker image
2. ✅ Pushes to AWS ECR
3. ✅ Applies Terraform changes
4. ✅ Updates Lambda function
5. ✅ Runs health check

---

### Option 2: Local Development

#### Windows (PowerShell)

1. **Double-click `run.ps1`** or run in PowerShell:
   ```powershell
   .\run.ps1
   ```

2. The script will automatically:
   - ✅ Create a Python virtual environment
   - ✅ Install all dependencies
   - ✅ Start the server

3. Open **http://127.0.0.1:8000** in your browser

> **Note:** For local development with AWS Bedrock, configure your AWS credentials:
> ```powershell
> $env:AWS_ACCESS_KEY_ID="your_access_key"
> $env:AWS_SECRET_ACCESS_KEY="your_secret_key"
> $env:AWS_REGION="ap-south-2"
> ```

#### Manual Setup

```bash
# 1. Create virtual environment
python -m venv .venv

# 2. Activate it
# Windows:
.\.venv\Scripts\Activate.ps1
# Linux/Mac:
source .venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Set AWS credentials (required)
export AWS_REGION=ap-south-2
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret

# 5. Run the server
python -m uvicorn main:app --reload --port 8000
```

---

## 🔑 AWS Bedrock Setup

### Enable Nova Micro Model

1. Go to **AWS Console** → **Amazon Bedrock**
2. Navigate to **Model access**
3. Request access to **Amazon Nova Micro**
4. Wait for approval (usually instant)

### IAM Permissions Required

Your IAM user/role needs these permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel",
                "ecr:*",
                "lambda:*",
                "apigateway:*",
                "logs:*",
                "iam:PassRole"
            ],
            "Resource": "*"
        }
    ]
}
```

---

## 📋 How to Use

1. **Upload Resume** - Drag & drop or click to upload your PDF resume
2. **Enter Job Details** - Paste a job description or enter a job role
3. **Click "Run ATS Scan"** - Get instant analysis
4. **Review Results**:
   - 📊 **ATS Match Score** (0-100)
   - ✅ **Matched Keywords** - Skills found in your resume
   - ❌ **Missing Keywords** - Skills you should add
   - 💡 **Improvement Tips** - Exactly what to fix and how

---

## 🎯 What This Tool Does

| It Does ✓ | It Doesn't ✗ |
|-----------|--------------|
| Keyword matching like real ATS | Rewrite your resume |
| Identify missing skills | Compare you to other candidates |
| Give specific, actionable fixes | Use fancy ML/AI buzzwords |
| Explain why ATS penalizes you | Store your data anywhere |

---

## 🧠 Scoring Logic

- **70%** → Technical keyword match (tools, languages, frameworks)
- **20%** → Role relevance (job title alignment)
- **10%** → Resume structure (Skills, Projects, Experience sections)

---

## 📁 Project Structure

```
ATS Checker/
├── .github/
│   └── workflows/
│       └── deploy.yml       # GitHub Actions CI/CD
├── terraform/
│   ├── main.tf              # AWS infrastructure
│   ├── variables.tf         # Configuration
│   └── outputs.tf           # Deployment outputs
├── static/
│   ├── index.html           # Frontend page
│   ├── styles.css           # Dark theme styling
│   └── script.js            # Client-side logic
├── .dockerignore            # Docker build exclusions
├── .env.example             # Environment template
├── .gitignore               # Git exclusions
├── Dockerfile               # Lambda container
├── main.py                  # FastAPI backend
├── requirements.txt         # Python dependencies
├── run.ps1                  # Local dev script
└── README.md                # This file
```

---

## 💰 Cost Optimization (Free Tier)

This project is optimized for AWS Free Tier:

| Service | Free Tier | Our Config |
|---------|-----------|------------|
| Lambda | 1M requests/month | ✅ Used |
| API Gateway | 1M requests/month | ✅ HTTP API (cheaper) |
| ECR | 500MB storage | ✅ 3 image limit |
| CloudWatch | 5GB logs | ✅ 7-day retention |
| Bedrock | Pay per token | ~$0.00003/analysis |

**Estimated cost:** Near $0 for moderate usage (< 1000 scans/month)

---

## ⚠️ Troubleshooting

### "AccessDeniedException" for Bedrock
- Ensure Nova Micro is enabled in Bedrock console
- Check IAM permissions include `bedrock:InvokeModel`

### "Repository does not exist" in CI/CD
- Run `terraform apply` locally first to create ECR repository
- Then push to trigger GitHub Actions

### Lambda timeout
- Increase timeout in `terraform/main.tf` (max 900 seconds)
- Current setting: 30 seconds

### Cold start delays
- First request after idle may take 5-10 seconds
- Subsequent requests are fast (~1-2 seconds)

---

## 📝 Tech Stack

- **Frontend**: HTML + CSS + Vanilla JavaScript
- **Backend**: FastAPI (Python 3.11)
- **LLM**: AWS Bedrock Nova Micro
- **Infrastructure**: Terraform, AWS Lambda, API Gateway
- **CI/CD**: GitHub Actions
- **PDF Parsing**: pdfplumber (+ pytesseract OCR fallback)

---

## 🎓 Demo Flow (For Presentation)

1. Upload your resume
2. Paste a job description
3. Click scan → show score
4. Change JD to a different role
5. Click scan again → show score drops/changes
6. Explain: "This is how ATS keyword filtering works"

---

Built with ❤️ for understanding ATS, not fighting it.

**Deployed on AWS Bedrock** | **Region: ap-south-2 (Hyderabad)**
