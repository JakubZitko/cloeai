/**
 * Project Detail Page
 */

import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import axios from 'axios';

export default function ProjectPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [project, setProject] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadProject();
    const interval = setInterval(loadProject, 3000); // Poll every 3 seconds
    return () => clearInterval(interval);
  }, [id]);

  const loadProject = async () => {
    try {
      const response = await axios.get(`/api/videos/project/${id}`);
      setProject(response.data.project);
    } catch (error) {
      console.error('Failed to load project:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  if (!project) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-center">
          <p className="text-gray-400 text-lg">Project not found</p>
          <button
            onClick={() => navigate('/dashboard')}
            className="mt-4 text-blue-400 hover:text-blue-300"
          >
            Back to Dashboard
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-900">
      <div className="max-w-5xl mx-auto px-4 py-12">
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
          <div className="flex items-start justify-between mb-8">
            <div>
              <h1 className="text-3xl font-bold text-white mb-2">{project.name}</h1>
              <p className="text-gray-400">Created {new Date(project.createdAt).toLocaleDateString()}</p>
            </div>
            <StatusBadge status={project.status} />
          </div>

          {/* Progress */}
          {project.progress < 100 && (
            <div className="mb-8">
              <div className="flex items-center justify-between text-sm text-gray-400 mb-2">
                <span>Processing...</span>
                <span>{project.progress}%</span>
              </div>
              <div className="w-full bg-gray-700 rounded-full h-3">
                <div
                  className="bg-blue-500 h-3 rounded-full transition-all"
                  style={{ width: `${project.progress}%` }}
                />
              </div>
            </div>
          )}

          {/* Analysis Results */}
          {project.analysis && (
            <div className="mb-8">
              <h2 className="text-xl font-semibold text-white mb-4">Analysis Results</h2>
              <div className="bg-gray-700 rounded-lg p-6 space-y-4">
                {project.analysis.product_type && (
                  <div>
                    <span className="text-gray-400">Product Type:</span>
                    <span className="ml-2 text-white">{project.analysis.product_type}</span>
                  </div>
                )}
                {project.analysis.visual_style && (
                  <div>
                    <span className="text-gray-400">Visual Style:</span>
                    <span className="ml-2 text-white">{project.analysis.visual_style.overall}</span>
                  </div>
                )}
                {project.analysis.pacing && (
                  <div>
                    <span className="text-gray-400">Pacing:</span>
                    <span className="ml-2 text-white">{project.analysis.pacing.speed}</span>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Reference Videos */}
          {project.references && (
            <div className="mb-8">
              <h2 className="text-xl font-semibold text-white mb-4">Reference Videos</h2>
              <p className="text-gray-400 mb-4">
                Found {project.references.total_count} reference videos
              </p>
            </div>
          )}

          {/* Error Message */}
          {project.errorMessage && (
            <div className="mb-8 p-4 bg-red-900/20 border border-red-500 rounded-lg">
              <p className="text-red-400">Error: {project.errorMessage}</p>
            </div>
          )}

          {/* Completion Message */}
          {project.status === 'completed' && (
            <div className="p-4 bg-green-900/20 border border-green-500 rounded-lg">
              <h2 className="text-xl font-semibold text-green-400 mb-2">Analysis Complete!</h2>
              <p className="text-gray-300">
                Your video has been analyzed with AI. Review the analysis results and reference videos above.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function StatusBadge({ status }) {
  const colors = {
    draft: 'bg-gray-600',
    analyzing: 'bg-yellow-600',
    completed: 'bg-green-600',
    failed: 'bg-red-600'
  };

  return (
    <span className={`px-3 py-1 rounded-full text-sm font-medium text-white ${colors[status] || colors.draft}`}>
      {status}
    </span>
  );
}
