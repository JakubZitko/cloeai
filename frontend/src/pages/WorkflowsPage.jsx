/**
 * Workflows Page - Shows learned and created workflows
 * Monochrome Design: black, white, gray only
 */

import { useState, useEffect } from 'react';
import axios from 'axios';
import Layout from '../components/Layout';

export default function WorkflowsPage({ user }) {
  const [workflows, setWorkflows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedWorkflow, setSelectedWorkflow] = useState(null);
  const [showCreateModal, setShowCreateModal] = useState(false);

  useEffect(() => {
    loadWorkflows();
  }, []);

  const loadWorkflows = async () => {
    try {
      const response = await axios.get('/api/cloe/workflows');
      setWorkflows(response.data.workflows);
    } catch (error) {
      console.error('Failed to load workflows:', error);
    } finally {
      setLoading(false);
    }
  };

  const deleteWorkflow = async (workflowId) => {
    if (!confirm('Are you sure you want to delete this workflow?')) return;

    try {
      await axios.delete(`/api/cloe/workflows/${workflowId}`);
      setWorkflows(workflows.filter(w => w.id !== workflowId));
      setSelectedWorkflow(null);
    } catch (error) {
      console.error('Failed to delete workflow:', error);
    }
  };

  return (
    <Layout user={user}>
      <div className="p-8">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold mb-2" style={{ color: '#fafafa' }}>Workflows</h1>
            <p style={{ color: '#737373' }}>Automated sequences Cloe has learned from your patterns</p>
          </div>
          <button
            onClick={() => setShowCreateModal(true)}
            className="px-4 py-2 rounded-lg transition-colors flex items-center gap-2"
            style={{ backgroundColor: '#fafafa', color: '#0a0a0a' }}
          >
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 4v16m8-8H4" />
            </svg>
            Create Workflow
          </button>
        </div>

        {/* Workflow List */}
        {loading ? (
          <div className="flex items-center justify-center py-16">
            <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2" style={{ borderColor: '#525252' }}></div>
          </div>
        ) : workflows.length > 0 ? (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {workflows.map(workflow => (
              <div
                key={workflow.id}
                className="rounded-lg p-6 transition-colors"
                style={{ backgroundColor: '#1a1a1a' }}
              >
                <div className="flex items-start justify-between mb-4">
                  <div>
                    <h3 className="text-lg font-semibold" style={{ color: '#fafafa' }}>{workflow.name}</h3>
                    <p className="text-sm mt-1" style={{ color: '#525252' }}>
                      {workflow.steps.length} steps
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="px-2 py-1 rounded text-xs" style={{ backgroundColor: '#262626', color: '#a3a3a3' }}>
                      Used {workflow.frequency}x
                    </span>
                  </div>
                </div>

                {/* Steps Preview */}
                <div className="space-y-2 mb-4">
                  {workflow.steps.slice(0, 3).map((step, index) => (
                    <div key={index} className="flex items-center gap-3">
                      <div className="w-6 h-6 rounded-full flex items-center justify-center text-xs" style={{ backgroundColor: '#262626', color: '#737373' }}>
                        {index + 1}
                      </div>
                      <span className="text-sm" style={{ color: '#a3a3a3' }}>
                        {step.action} in <span style={{ color: '#fafafa' }}>{step.app}</span>
                      </span>
                    </div>
                  ))}
                  {workflow.steps.length > 3 && (
                    <p className="text-sm pl-9" style={{ color: '#525252' }}>
                      +{workflow.steps.length - 3} more steps
                    </p>
                  )}
                </div>

                {/* Triggers */}
                {workflow.triggerPatterns?.length > 0 && (
                  <div className="mb-4">
                    <p className="text-xs mb-2" style={{ color: '#525252' }}>Trigger phrases:</p>
                    <div className="flex flex-wrap gap-2">
                      {workflow.triggerPatterns.slice(0, 3).map((trigger, i) => (
                        <span key={i} className="px-2 py-1 rounded text-xs" style={{ backgroundColor: '#262626', color: '#737373' }}>
                          "{trigger}"
                        </span>
                      ))}
                    </div>
                  </div>
                )}

                {/* Actions */}
                <div className="flex items-center justify-between pt-4" style={{ borderTop: '1px solid #262626' }}>
                  <span className="text-xs" style={{ color: '#525252' }}>
                    Last used: {new Date(workflow.lastUsed).toLocaleDateString()}
                  </span>
                  <div className="flex gap-2">
                    <button
                      onClick={() => setSelectedWorkflow(workflow)}
                      className="px-3 py-1 rounded text-sm"
                      style={{ backgroundColor: '#262626', color: '#fafafa' }}
                    >
                      View
                    </button>
                    <button
                      onClick={() => deleteWorkflow(workflow.id)}
                      className="px-3 py-1 rounded text-sm"
                      style={{ backgroundColor: '#262626', color: '#737373' }}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-16">
            <svg className="w-16 h-16 mx-auto mb-4" style={{ color: '#525252' }} fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" />
            </svg>
            <p className="text-lg" style={{ color: '#737373' }}>No workflows yet</p>
            <p className="mt-2" style={{ color: '#525252' }}>Cloe will learn workflows from your repeated patterns</p>
            <button
              onClick={() => setShowCreateModal(true)}
              className="mt-4 px-6 py-2 rounded-lg transition-colors"
              style={{ backgroundColor: '#fafafa', color: '#0a0a0a' }}
            >
              Create Your First Workflow
            </button>
          </div>
        )}

        {/* Workflow Detail Modal */}
        {selectedWorkflow && (
          <WorkflowModal
            workflow={selectedWorkflow}
            onClose={() => setSelectedWorkflow(null)}
            onDelete={() => {
              deleteWorkflow(selectedWorkflow.id);
            }}
          />
        )}

        {/* Create Workflow Modal */}
        {showCreateModal && (
          <CreateWorkflowModal
            onClose={() => setShowCreateModal(false)}
            onCreate={(workflow) => {
              setWorkflows([...workflows, workflow]);
              setShowCreateModal(false);
            }}
          />
        )}
      </div>
    </Layout>
  );
}

function WorkflowModal({ workflow, onClose, onDelete }) {
  return (
    <div className="fixed inset-0 flex items-center justify-center z-50" style={{ backgroundColor: 'rgba(0,0,0,0.8)' }}>
      <div className="rounded-lg p-6 w-full max-w-lg mx-4" style={{ backgroundColor: '#1a1a1a' }}>
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold" style={{ color: '#fafafa' }}>{workflow.name}</h2>
          <button onClick={onClose} style={{ color: '#525252' }}>
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* All Steps */}
        <div className="space-y-3 mb-6">
          <h3 className="text-sm font-medium" style={{ color: '#525252' }}>Steps</h3>
          {workflow.steps.map((step, index) => (
            <div key={index} className="flex items-start gap-3 p-3 rounded-lg" style={{ backgroundColor: '#262626' }}>
              <div className="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0" style={{ backgroundColor: '#fafafa', color: '#0a0a0a' }}>
                <span className="text-sm font-medium">{index + 1}</span>
              </div>
              <div>
                <p style={{ color: '#fafafa' }}>{step.action}</p>
                <p className="text-sm" style={{ color: '#737373' }}>in {step.app}</p>
                {step.details && (
                  <p className="text-xs mt-1" style={{ color: '#525252' }}>{step.details}</p>
                )}
              </div>
            </div>
          ))}
        </div>

        {/* Trigger Phrases */}
        {workflow.triggerPatterns?.length > 0 && (
          <div className="mb-6">
            <h3 className="text-sm font-medium mb-2" style={{ color: '#525252' }}>Trigger Phrases</h3>
            <div className="flex flex-wrap gap-2">
              {workflow.triggerPatterns.map((trigger, i) => (
                <span key={i} className="px-3 py-1 rounded-full text-sm" style={{ backgroundColor: '#262626', color: '#a3a3a3' }}>
                  "{trigger}"
                </span>
              ))}
            </div>
          </div>
        )}

        {/* Stats */}
        <div className="grid grid-cols-2 gap-4 mb-6">
          <div className="rounded-lg p-3" style={{ backgroundColor: '#262626' }}>
            <p className="text-sm" style={{ color: '#525252' }}>Times Used</p>
            <p className="text-xl font-semibold" style={{ color: '#fafafa' }}>{workflow.frequency}</p>
          </div>
          <div className="rounded-lg p-3" style={{ backgroundColor: '#262626' }}>
            <p className="text-sm" style={{ color: '#525252' }}>Last Used</p>
            <p className="text-xl font-semibold" style={{ color: '#fafafa' }}>
              {new Date(workflow.lastUsed).toLocaleDateString()}
            </p>
          </div>
        </div>

        {/* Actions */}
        <div className="flex gap-3">
          <button
            onClick={onClose}
            className="flex-1 py-2 rounded-lg transition-colors"
            style={{ backgroundColor: '#262626', color: '#fafafa' }}
          >
            Close
          </button>
          <button
            onClick={onDelete}
            className="px-4 py-2 rounded-lg transition-colors"
            style={{ backgroundColor: '#262626', color: '#737373' }}
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  );
}

function CreateWorkflowModal({ onClose, onCreate }) {
  const [name, setName] = useState('');
  const [steps, setSteps] = useState([{ app: '', action: '', details: '' }]);
  const [triggers, setTriggers] = useState(['']);
  const [saving, setSaving] = useState(false);

  const addStep = () => {
    setSteps([...steps, { app: '', action: '', details: '' }]);
  };

  const updateStep = (index, field, value) => {
    const newSteps = [...steps];
    newSteps[index][field] = value;
    setSteps(newSteps);
  };

  const removeStep = (index) => {
    if (steps.length > 1) {
      setSteps(steps.filter((_, i) => i !== index));
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);

    try {
      const response = await axios.post('/api/cloe/workflows', {
        name,
        steps: steps.filter(s => s.app && s.action),
        triggerPatterns: triggers.filter(t => t.trim())
      });
      onCreate(response.data.workflow);
    } catch (error) {
      console.error('Failed to create workflow:', error);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 flex items-center justify-center z-50 overflow-y-auto" style={{ backgroundColor: 'rgba(0,0,0,0.8)' }}>
      <div className="rounded-lg p-6 w-full max-w-lg mx-4 my-8" style={{ backgroundColor: '#1a1a1a' }}>
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold" style={{ color: '#fafafa' }}>Create Workflow</h2>
          <button onClick={onClose} style={{ color: '#525252' }}>
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Name */}
          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: '#a3a3a3' }}>
              Workflow Name
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g., Morning routine"
              className="w-full px-4 py-2 rounded-lg focus:outline-none"
              style={{ backgroundColor: '#262626', color: '#fafafa', border: '1px solid #262626' }}
              required
            />
          </div>

          {/* Steps */}
          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: '#a3a3a3' }}>
              Steps
            </label>
            <div className="space-y-3">
              {steps.map((step, index) => (
                <div key={index} className="flex gap-2">
                  <div className="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 mt-2" style={{ backgroundColor: '#fafafa', color: '#0a0a0a' }}>
                    <span className="text-sm">{index + 1}</span>
                  </div>
                  <div className="flex-1 space-y-2">
                    <input
                      type="text"
                      value={step.app}
                      onChange={(e) => updateStep(index, 'app', e.target.value)}
                      placeholder="App name"
                      className="w-full px-3 py-2 rounded-lg text-sm focus:outline-none"
                      style={{ backgroundColor: '#262626', color: '#fafafa', border: '1px solid #262626' }}
                    />
                    <input
                      type="text"
                      value={step.action}
                      onChange={(e) => updateStep(index, 'action', e.target.value)}
                      placeholder="Action description"
                      className="w-full px-3 py-2 rounded-lg text-sm focus:outline-none"
                      style={{ backgroundColor: '#262626', color: '#fafafa', border: '1px solid #262626' }}
                    />
                  </div>
                  {steps.length > 1 && (
                    <button
                      type="button"
                      onClick={() => removeStep(index)}
                      className="mt-2"
                      style={{ color: '#525252' }}
                    >
                      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  )}
                </div>
              ))}
            </div>
            <button
              type="button"
              onClick={addStep}
              className="mt-3 text-sm flex items-center gap-1"
              style={{ color: '#737373' }}
            >
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 4v16m8-8H4" />
              </svg>
              Add Step
            </button>
          </div>

          {/* Triggers */}
          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: '#a3a3a3' }}>
              Trigger Phrases (optional)
            </label>
            <input
              type="text"
              value={triggers[0]}
              onChange={(e) => setTriggers([e.target.value])}
              placeholder="e.g., start my morning routine"
              className="w-full px-4 py-2 rounded-lg focus:outline-none"
              style={{ backgroundColor: '#262626', color: '#fafafa', border: '1px solid #262626' }}
            />
            <p className="text-xs mt-1" style={{ color: '#525252' }}>
              Say this to Cloe to trigger the workflow
            </p>
          </div>

          {/* Actions */}
          <div className="flex gap-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-2 rounded-lg transition-colors"
              style={{ backgroundColor: '#262626', color: '#fafafa' }}
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={saving || !name}
              className="flex-1 py-2 rounded-lg transition-colors disabled:opacity-50"
              style={{ backgroundColor: '#fafafa', color: '#0a0a0a' }}
            >
              {saving ? 'Creating...' : 'Create Workflow'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
