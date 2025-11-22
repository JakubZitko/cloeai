/**
 * Upload Page
 * Enhanced with drag-and-drop and real progress tracking
 */

import { useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';

export default function UploadPage() {
  const navigate = useNavigate();
  const [file, setFile] = useState(null);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [uploadPhase, setUploadPhase] = useState('idle'); // idle, preparing, uploading, processing
  const [error, setError] = useState(null);
  const [dragActive, setDragActive] = useState(false);
  const fileInputRef = useRef(null);

  const handleFileSelect = (selectedFile) => {
    setError(null);

    // Validate file type
    const validTypes = ['video/mp4', 'video/quicktime', 'video/x-msvideo', 'video/webm', 'video/mpeg'];
    if (!validTypes.includes(selectedFile.type)) {
      setError('Please select a valid video file (MP4, MOV, AVI, WebM)');
      return;
    }

    // Validate file size (500MB max)
    const maxSize = 500 * 1024 * 1024;
    if (selectedFile.size > maxSize) {
      setError('File size must be less than 500MB');
      return;
    }

    setFile(selectedFile);
    if (!name) {
      setName(selectedFile.name.replace(/\.[^/.]+$/, ''));
    }
  };

  const handleFileChange = (e) => {
    const selectedFile = e.target.files[0];
    if (selectedFile) {
      handleFileSelect(selectedFile);
    }
  };

  // Drag and drop handlers
  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
  };

  const handleDragIn = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(true);
  };

  const handleDragOut = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFileSelect(e.dataTransfer.files[0]);
    }
  };

  const handleDropzoneClick = () => {
    fileInputRef.current?.click();
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);

    if (!file) {
      setError('Please select a video file');
      return;
    }

    setUploading(true);
    setUploadPhase('preparing');
    setProgress(0);

    const formData = new FormData();
    formData.append('video', file);
    formData.append('name', name);
    formData.append('description', description);

    try {
      setUploadPhase('uploading');

      const response = await axios.post('/api/videos/upload', formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        },
        onUploadProgress: (progressEvent) => {
          const percentCompleted = Math.round(
            (progressEvent.loaded * 100) / progressEvent.total
          );
          setProgress(percentCompleted);

          if (percentCompleted === 100) {
            setUploadPhase('processing');
          }
        }
      });

      // Redirect to project page
      navigate(`/project/${response.data.project.id}`);

    } catch (err) {
      console.error('Upload failed:', err);
      setError(err.response?.data?.error?.message || err.response?.data?.error || err.message || 'Upload failed');
      setUploading(false);
      setUploadPhase('idle');
      setProgress(0);
    }
  };

  const getProgressMessage = () => {
    switch (uploadPhase) {
      case 'preparing':
        return 'Preparing upload...';
      case 'uploading':
        return `Uploading video... ${progress}%`;
      case 'processing':
        return 'Processing...';
      default:
        return '';
    }
  };

  return (
    <div className="min-h-screen bg-gray-900">
      <div className="max-w-3xl mx-auto px-4 py-12">
        <div className="mb-8">
          <button
            onClick={() => navigate('/dashboard')}
            className="text-gray-400 hover:text-white flex items-center gap-2"
          >
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            <span>Back to Dashboard</span>
          </button>
        </div>

        <div className="bg-gray-800 rounded-lg p-8">
          <h1 className="text-3xl font-bold text-white mb-8">Create New Project</h1>

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Error Message */}
            {error && (
              <div className="p-4 bg-red-900/20 border border-red-500 rounded-lg">
                <p className="text-red-400">{error}</p>
              </div>
            )}

            {/* File Upload */}
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-2">
                Video File
              </label>
              <div
                onClick={handleDropzoneClick}
                onDrag={handleDrag}
                onDragEnter={handleDragIn}
                onDragLeave={handleDragOut}
                onDragOver={handleDrag}
                onDrop={handleDrop}
                className={`mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-dashed rounded-lg transition-colors cursor-pointer ${
                  dragActive
                    ? 'border-blue-500 bg-blue-900/20'
                    : file
                    ? 'border-green-500 bg-green-900/10'
                    : 'border-gray-600 hover:border-gray-500'
                }`}
              >
                <div className="space-y-1 text-center">
                  {file ? (
                    <div>
                      <svg className="mx-auto h-12 w-12 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <p className="text-white font-medium">{file.name}</p>
                      <p className="text-gray-400 text-sm">{(file.size / 1024 / 1024).toFixed(2)} MB</p>
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          setFile(null);
                          setName('');
                        }}
                        className="mt-2 text-sm text-red-400 hover:text-red-300"
                      >
                        Remove file
                      </button>
                    </div>
                  ) : (
                    <>
                      <svg className="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                        <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                      <div className="flex text-sm text-gray-400">
                        <span className="font-medium text-blue-400">Upload a file</span>
                        <p className="pl-1">or drag and drop</p>
                      </div>
                      <p className="text-xs text-gray-400">MP4, MOV, AVI, WebM up to 500MB</p>
                    </>
                  )}
                </div>
              </div>
              <input
                ref={fileInputRef}
                type="file"
                className="sr-only"
                accept="video/*"
                onChange={handleFileChange}
              />
            </div>

            {/* Project Name */}
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-2">
                Project Name
              </label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
                placeholder="My Awesome SaaS Video"
                required
              />
            </div>

            {/* Description */}
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-2">
                Description (Optional)
              </label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={4}
                className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
                placeholder="Tell us about your video..."
              />
            </div>

            {/* Upload Progress */}
            {uploading && (
              <div className="space-y-3">
                <div className="flex items-center justify-between text-sm text-gray-400">
                  <span className="flex items-center gap-2">
                    {uploadPhase === 'processing' ? (
                      <svg className="animate-spin h-4 w-4 text-blue-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                    ) : null}
                    {getProgressMessage()}
                  </span>
                  {uploadPhase === 'uploading' && <span>{progress}%</span>}
                </div>
                <div className="w-full bg-gray-700 rounded-full h-2 overflow-hidden">
                  <div
                    className={`h-2 rounded-full transition-all duration-300 ${
                      uploadPhase === 'processing' ? 'bg-yellow-500 animate-pulse' : 'bg-blue-500'
                    }`}
                    style={{ width: uploadPhase === 'processing' ? '100%' : `${progress}%` }}
                  />
                </div>
                {/* Phase indicators */}
                <div className="flex justify-between text-xs text-gray-500">
                  <span className={uploadPhase === 'preparing' ? 'text-blue-400' : ''}>Preparing</span>
                  <span className={uploadPhase === 'uploading' ? 'text-blue-400' : ''}>Uploading</span>
                  <span className={uploadPhase === 'processing' ? 'text-yellow-400' : ''}>Processing</span>
                </div>
              </div>
            )}

            {/* Submit Button */}
            <div className="flex gap-4">
              <button
                type="submit"
                disabled={uploading || !file}
                className="flex-1 py-3 bg-blue-500 text-white rounded-lg font-semibold hover:bg-blue-600 disabled:bg-gray-600 disabled:cursor-not-allowed transition-colors"
              >
                {uploading ? 'Uploading...' : 'Start Analysis'}
              </button>
              <button
                type="button"
                onClick={() => navigate('/dashboard')}
                disabled={uploading}
                className="px-6 py-3 bg-gray-700 text-white rounded-lg font-semibold hover:bg-gray-600 disabled:opacity-50 transition-colors"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
