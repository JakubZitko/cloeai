/**
 * Settings Page - Configure Cloe preferences
 * Monochrome Design: black, white, gray only
 */

import { useState, useEffect } from 'react';
import axios from 'axios';
import Layout from '../components/Layout';

export default function SettingsPage({ user }) {
  const [settings, setSettings] = useState({
    learningEnabled: true,
    nightModeEnabled: false,
    nightModeStart: '22:00',
    nightModeEnd: '06:00',
    syncEnabled: true,
    notifications: {
      taskComplete: true,
      learnedPattern: true,
      nightModeReport: true
    },
    privacy: {
      trackBrowsing: true,
      trackEmail: true,
      trackMessages: true,
      trackFiles: true
    }
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    try {
      const response = await axios.get('/api/cloe/settings');
      setSettings(response.data.settings);
    } catch (error) {
      console.error('Failed to load settings:', error);
    } finally {
      setLoading(false);
    }
  };

  const saveSettings = async () => {
    setSaving(true);
    try {
      await axios.put('/api/cloe/settings', settings);
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    } catch (error) {
      console.error('Failed to save settings:', error);
    } finally {
      setSaving(false);
    }
  };

  const updateSetting = (path, value) => {
    const newSettings = { ...settings };
    const keys = path.split('.');
    let obj = newSettings;
    for (let i = 0; i < keys.length - 1; i++) {
      obj = obj[keys[i]];
    }
    obj[keys[keys.length - 1]] = value;
    setSettings(newSettings);
  };

  if (loading) {
    return (
      <Layout user={user}>
        <div className="flex items-center justify-center h-full">
          <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2" style={{ borderColor: '#525252' }}></div>
        </div>
      </Layout>
    );
  }

  return (
    <Layout user={user}>
      <div className="p-8 max-w-3xl">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold mb-2" style={{ color: '#fafafa' }}>Settings</h1>
          <p style={{ color: '#737373' }}>Configure how Cloe works for you</p>
        </div>

        <div className="space-y-8">
          {/* Account Section */}
          <section className="rounded-lg p-6" style={{ backgroundColor: '#1a1a1a' }}>
            <h2 className="text-lg font-semibold mb-4" style={{ color: '#fafafa' }}>Account</h2>
            <div className="flex items-center gap-4">
              <div className="w-16 h-16 rounded-full flex items-center justify-center" style={{ backgroundColor: '#262626' }}>
                <span className="text-2xl font-bold" style={{ color: '#a3a3a3' }}>
                  {user?.name?.charAt(0) || 'U'}
                </span>
              </div>
              <div>
                <p className="font-medium" style={{ color: '#fafafa' }}>{user?.name}</p>
                <p style={{ color: '#525252' }}>{user?.email}</p>
              </div>
            </div>
          </section>

          {/* Learning Section */}
          <section className="rounded-lg p-6" style={{ backgroundColor: '#1a1a1a' }}>
            <h2 className="text-lg font-semibold mb-4" style={{ color: '#fafafa' }}>Learning</h2>
            <div className="space-y-4">
              <Toggle
                label="Enable Learning"
                description="Allow Cloe to learn from your usage patterns"
                checked={settings.learningEnabled}
                onChange={(v) => updateSetting('learningEnabled', v)}
              />
              <Toggle
                label="Sync Across Devices"
                description="Sync learned patterns with your other devices"
                checked={settings.syncEnabled}
                onChange={(v) => updateSetting('syncEnabled', v)}
              />
            </div>
          </section>

          {/* Night Mode Section */}
          <section className="rounded-lg p-6" style={{ backgroundColor: '#1a1a1a' }}>
            <h2 className="text-lg font-semibold mb-4" style={{ color: '#fafafa' }}>Night Mode</h2>
            <p className="text-sm mb-4" style={{ color: '#525252' }}>
              Let Cloe work on tasks autonomously while you're away
            </p>
            <div className="space-y-4">
              <Toggle
                label="Enable Night Mode"
                description="Allow Cloe to execute tasks during scheduled hours"
                checked={settings.nightModeEnabled}
                onChange={(v) => updateSetting('nightModeEnabled', v)}
              />
              {settings.nightModeEnabled && (
                <div className="flex gap-4 pl-4" style={{ borderLeft: '2px solid #262626' }}>
                  <div>
                    <label className="block text-sm mb-1" style={{ color: '#525252' }}>Start Time</label>
                    <input
                      type="time"
                      value={settings.nightModeStart}
                      onChange={(e) => updateSetting('nightModeStart', e.target.value)}
                      className="px-3 py-2 rounded-lg focus:outline-none"
                      style={{ backgroundColor: '#262626', color: '#fafafa', border: '1px solid #262626' }}
                    />
                  </div>
                  <div>
                    <label className="block text-sm mb-1" style={{ color: '#525252' }}>End Time</label>
                    <input
                      type="time"
                      value={settings.nightModeEnd}
                      onChange={(e) => updateSetting('nightModeEnd', e.target.value)}
                      className="px-3 py-2 rounded-lg focus:outline-none"
                      style={{ backgroundColor: '#262626', color: '#fafafa', border: '1px solid #262626' }}
                    />
                  </div>
                </div>
              )}
            </div>
          </section>

          {/* Privacy Section */}
          <section className="rounded-lg p-6" style={{ backgroundColor: '#1a1a1a' }}>
            <h2 className="text-lg font-semibold mb-4" style={{ color: '#fafafa' }}>Privacy</h2>
            <p className="text-sm mb-4" style={{ color: '#525252' }}>
              Control what Cloe can see and learn from
            </p>
            <div className="space-y-4">
              <Toggle
                label="Browser Activity"
                description="Learn from websites you visit"
                checked={settings.privacy.trackBrowsing}
                onChange={(v) => updateSetting('privacy.trackBrowsing', v)}
              />
              <Toggle
                label="Email"
                description="Learn contacts and patterns from Mail.app"
                checked={settings.privacy.trackEmail}
                onChange={(v) => updateSetting('privacy.trackEmail', v)}
              />
              <Toggle
                label="Messages"
                description="Learn from Messages.app conversations"
                checked={settings.privacy.trackMessages}
                onChange={(v) => updateSetting('privacy.trackMessages', v)}
              />
              <Toggle
                label="Files"
                description="Learn from files you open and save"
                checked={settings.privacy.trackFiles}
                onChange={(v) => updateSetting('privacy.trackFiles', v)}
              />
            </div>
          </section>

          {/* Notifications Section */}
          <section className="rounded-lg p-6" style={{ backgroundColor: '#1a1a1a' }}>
            <h2 className="text-lg font-semibold mb-4" style={{ color: '#fafafa' }}>Notifications</h2>
            <div className="space-y-4">
              <Toggle
                label="Task Completed"
                description="Notify when Cloe completes a task"
                checked={settings.notifications.taskComplete}
                onChange={(v) => updateSetting('notifications.taskComplete', v)}
              />
              <Toggle
                label="New Pattern Learned"
                description="Notify when Cloe learns a new pattern"
                checked={settings.notifications.learnedPattern}
                onChange={(v) => updateSetting('notifications.learnedPattern', v)}
              />
              <Toggle
                label="Night Mode Report"
                description="Get a summary of Night Mode activity"
                checked={settings.notifications.nightModeReport}
                onChange={(v) => updateSetting('notifications.nightModeReport', v)}
              />
            </div>
          </section>

          {/* Data Section */}
          <section className="rounded-lg p-6" style={{ backgroundColor: '#1a1a1a' }}>
            <h2 className="text-lg font-semibold mb-4" style={{ color: '#fafafa' }}>Data</h2>
            <div className="space-y-4">
              <button
                className="w-full py-3 rounded-lg text-left px-4 flex items-center justify-between transition-colors"
                style={{ backgroundColor: '#262626', color: '#fafafa' }}
              >
                <span>Export Your Data</span>
                <svg className="w-5 h-5" style={{ color: '#525252' }} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                </svg>
              </button>
              <button
                className="w-full py-3 rounded-lg text-left px-4 flex items-center justify-between transition-colors"
                style={{ backgroundColor: '#262626', color: '#737373' }}
              >
                <span>Clear All Learned Data</span>
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </button>
            </div>
          </section>

          {/* Save Button */}
          <div className="flex justify-end">
            <button
              onClick={saveSettings}
              disabled={saving}
              className="px-6 py-3 rounded-lg font-medium transition-colors disabled:opacity-50"
              style={{
                backgroundColor: saved ? '#262626' : '#fafafa',
                color: saved ? '#a3a3a3' : '#0a0a0a'
              }}
            >
              {saving ? 'Saving...' : saved ? 'Saved' : 'Save Changes'}
            </button>
          </div>
        </div>
      </div>
    </Layout>
  );
}

function Toggle({ label, description, checked, onChange }) {
  return (
    <div className="flex items-center justify-between">
      <div>
        <p style={{ color: '#fafafa' }}>{label}</p>
        <p className="text-sm" style={{ color: '#525252' }}>{description}</p>
      </div>
      <button
        onClick={() => onChange(!checked)}
        className="relative w-12 h-6 rounded-full transition-colors"
        style={{ backgroundColor: checked ? '#fafafa' : '#262626' }}
      >
        <span
          className="absolute top-1 w-4 h-4 rounded-full transition-transform"
          style={{
            backgroundColor: checked ? '#0a0a0a' : '#525252',
            left: checked ? '28px' : '4px'
          }}
        />
      </button>
    </div>
  );
}
