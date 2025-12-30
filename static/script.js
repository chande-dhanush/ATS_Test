/**
 * Mini ATS Resume Analyzer - Client-side Logic
 * Handles file upload, API calls, and result rendering
 */

// DOM Elements
const uploadArea = document.getElementById('upload-area');
const uploadContent = document.getElementById('upload-content');
const fileInput = document.getElementById('resume-file');
const fileInfo = document.getElementById('file-info');
const fileName = document.getElementById('file-name');
const fileSize = document.getElementById('file-size');
const removeFileBtn = document.getElementById('remove-file');
const uploadError = document.getElementById('upload-error');

const jobInput = document.getElementById('job-input');
const charCount = document.getElementById('char-count');

const scanButton = document.getElementById('scan-button');
const buttonText = scanButton.querySelector('.button-text');
const buttonLoader = scanButton.querySelector('.button-loader');
const scanStatus = document.getElementById('scan-status');

const resultsSection = document.getElementById('results-section');
const scoreValue = document.getElementById('score-value');
const progressFill = document.getElementById('progress-fill');
const scoreDescription = document.getElementById('score-description');
const matchedKeywords = document.getElementById('matched-keywords');
const missingKeywords = document.getElementById('missing-keywords');
const tipsList = document.getElementById('tips-list');

// State
let selectedFile = null;
let resumeText = '';

// Constants
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

// ============================================
// File Upload Handling
// ============================================

uploadArea.addEventListener('click', () => {
    if (!selectedFile) {
        fileInput.click();
    }
});

uploadArea.addEventListener('dragover', (e) => {
    e.preventDefault();
    uploadArea.classList.add('drag-over');
});

uploadArea.addEventListener('dragleave', () => {
    uploadArea.classList.remove('drag-over');
});

uploadArea.addEventListener('drop', (e) => {
    e.preventDefault();
    uploadArea.classList.remove('drag-over');

    const files = e.dataTransfer.files;
    if (files.length > 0) {
        handleFileSelect(files[0]);
    }
});

fileInput.addEventListener('change', (e) => {
    if (e.target.files.length > 0) {
        handleFileSelect(e.target.files[0]);
    }
});

removeFileBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    clearFile();
});

function handleFileSelect(file) {
    uploadError.textContent = '';

    // Validate file type
    if (!file.name.toLowerCase().endsWith('.pdf')) {
        showUploadError('Please upload a PDF file');
        return;
    }

    // Validate file size
    if (file.size > MAX_FILE_SIZE) {
        showUploadError('File size exceeds 5MB limit');
        return;
    }

    selectedFile = file;
    showFileInfo(file);
    updateScanButton();
}

function showFileInfo(file) {
    uploadContent.hidden = true;
    fileInfo.hidden = false;
    fileName.textContent = file.name;
    fileSize.textContent = formatFileSize(file.size);
}

function clearFile() {
    selectedFile = null;
    resumeText = '';
    fileInput.value = '';
    uploadContent.hidden = false;
    fileInfo.hidden = true;
    uploadError.textContent = '';
    updateScanButton();
}

function showUploadError(message) {
    uploadError.textContent = message;
    clearFile();
}

function formatFileSize(bytes) {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

// ============================================
// Job Input Handling
// ============================================

jobInput.addEventListener('input', () => {
    const length = jobInput.value.length;
    charCount.textContent = `${length} character${length !== 1 ? 's' : ''}`;
    updateScanButton();
});

// ============================================
// Scan Button State
// ============================================

function updateScanButton() {
    const hasFile = selectedFile !== null;
    const hasJob = jobInput.value.trim().length > 0;
    scanButton.disabled = !(hasFile && hasJob);
}

// ============================================
// API Calls & Scanning
// ============================================

scanButton.addEventListener('click', startScan);

async function startScan() {
    if (!selectedFile || !jobInput.value.trim()) return;

    setLoading(true);
    hideResults();

    try {
        // Step 1: Parse Resume
        setStatus('Extracting text from resume...');
        resumeText = await parseResume(selectedFile);

        // Step 2: Analyze
        setStatus('Scanning like an ATS...');
        const analysis = await analyzeResume(resumeText, jobInput.value.trim());

        // Step 3: Display Results
        setStatus('');
        displayResults(analysis);

    } catch (error) {
        console.error('Scan error:', error);
        setStatus(`❌ ${error.message}`);
    } finally {
        setLoading(false);
    }
}

async function parseResume(file) {
    const formData = new FormData();
    formData.append('file', file);

    const response = await fetch('/parse-resume', {
        method: 'POST',
        body: formData
    });

    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.detail || 'Failed to parse resume');
    }

    const data = await response.json();
    return data.resume_text;
}

async function analyzeResume(resumeText, jobInput) {
    const response = await fetch('/analyze', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            resume_text: resumeText,
            job_input: jobInput
        })
    });

    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.detail || 'Analysis failed');
    }

    return await response.json();
}

function setLoading(isLoading) {
    scanButton.disabled = isLoading;
    buttonText.hidden = isLoading;
    buttonLoader.hidden = !isLoading;
}

function setStatus(message) {
    scanStatus.textContent = message;
}

// ============================================
// Results Display
// ============================================

function hideResults() {
    resultsSection.hidden = true;
}

function displayResults(data) {
    // Show results section
    resultsSection.hidden = false;

    // Animate score
    animateScore(data.score);

    // Set score description
    scoreDescription.textContent = getScoreDescription(data.score);

    // Display keywords
    renderKeywords(matchedKeywords, data.matched_keywords, 'matched');
    renderKeywords(missingKeywords, data.missing_keywords, 'missing');

    // Display tips
    renderTips(data.tips);

    // Scroll to results
    setTimeout(() => {
        resultsSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 100);
}

function animateScore(targetScore) {
    const duration = 1000;
    const startTime = performance.now();

    function update(currentTime) {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);

        // Easing function (ease-out cubic)
        const eased = 1 - Math.pow(1 - progress, 3);

        const currentScore = Math.round(eased * targetScore);
        scoreValue.textContent = currentScore;
        progressFill.style.width = `${currentScore}%`;

        // Update progress bar color based on score
        if (currentScore >= 70) {
            progressFill.style.background = 'linear-gradient(90deg, #22c55e, #4ade80)';
        } else if (currentScore >= 50) {
            progressFill.style.background = 'linear-gradient(90deg, #f59e0b, #fbbf24)';
        } else {
            progressFill.style.background = 'linear-gradient(90deg, #ef4444, #f87171)';
        }

        if (progress < 1) {
            requestAnimationFrame(update);
        }
    }

    requestAnimationFrame(update);
}

function getScoreDescription(score) {
    if (score >= 80) {
        return 'Excellent match! Your resume is well-optimized for this role.';
    } else if (score >= 60) {
        return 'Good match with room for improvement. Add missing keywords to boost your score.';
    } else if (score >= 40) {
        return 'Moderate match. Consider tailoring your resume more closely to the job requirements.';
    } else {
        return 'Low match. Your resume may need significant updates to pass ATS filters.';
    }
}

function renderKeywords(container, keywords, type) {
    container.innerHTML = '';

    if (!keywords || keywords.length === 0) {
        const emptyTag = document.createElement('span');
        emptyTag.className = 'tag empty';
        emptyTag.textContent = type === 'matched' ? 'No matches found' : 'All keywords present!';
        container.appendChild(emptyTag);
        return;
    }

    keywords.forEach(keyword => {
        const tag = document.createElement('span');
        tag.className = `tag ${type}`;
        tag.textContent = keyword;
        container.appendChild(tag);
    });
}

function renderTips(tips) {
    tipsList.innerHTML = '';

    if (!tips || tips.length === 0) {
        tipsList.innerHTML = '<p style="color: var(--text-muted)">No specific tips at this time.</p>';
        return;
    }

    tips.forEach((tip, index) => {
        const tipElement = document.createElement('div');
        tipElement.className = 'tip-item';
        tipElement.style.animationDelay = `${index * 0.1}s`;

        tipElement.innerHTML = `
            <div class="tip-issue">❌ ${escapeHtml(tip.issue)}</div>
            <div class="tip-why">${escapeHtml(tip.why)}</div>
            <div class="tip-fix">${escapeHtml(tip.fix)}</div>
        `;

        tipsList.appendChild(tipElement);
    });
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// ============================================
// Initialize
// ============================================

updateScanButton();
