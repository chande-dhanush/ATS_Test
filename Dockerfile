# AWS Lambda Python 3.11 base image
FROM public.ecr.aws/lambda/python:3.11

# Set working directory
WORKDIR ${LAMBDA_TASK_ROOT}

# Copy requirements first for better caching
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .
COPY static/ static/

# Set the Lambda handler
CMD ["main.handler"]
