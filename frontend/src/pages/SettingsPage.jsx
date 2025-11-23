/**
 * Settings Page - Configure Cloe preferences
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
          <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500"></div>
        </div>
      </Layout>
    );
  }

  return (
    <Layout user={user}>
      <div className="p-8 max-w-3xl">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">Settings</h1>
          <p className="text-gray-400">Configure how Cloe works for you</p>
        </div>

        <div className="space-y-8">
          {/* Account Section */}
          <section className="bg-gray-800 rounded-lg p-6">
            <h2 className="text-lg font-semibold text-white mb-4">Account</h2>
            <div className="flex items-center gap-4">
              <div className="w-16 h-16 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center">
                <span className="text-2xl font-bold text-white">
                  {user?.name?.charAt(0) || 'U'}
                </span>
              </div>
              <div>
                <p className="text-white font-medium">{user?.name}</p>
                <p className="text-gray-400">{user?.email}</p>
              </div>
            </div>
          </section>

          {/* Learning Section */}
          <section className="bg-gray-800 rounded-lg p-6">
            <h2 className="text-lg font-semibold text-white mb-4">Learning</h2>
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
          <section className="bg-gray-800 rounded-lg p-6">
            <h2 className="text-lg font-semibold text-white mb-4">Night Mode</h2>
            <p className="text-gray-400 text-sm mb-4">
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
                <div className="flex gap-4 pl-4 border-l-2 border-gray-700">
                  <div>
                    <label className="block text-sm text-gray-400 mb-1">Start Time</label>
                    <input
                      type="time"
                      value={settings.nightModeStart}
                      onChange={(e) => updateSetting('nightModeStart', e.target.value)}
                      className="px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white focus:outline-none focus:border-blue-500"
                    />
                  </div>
                  <div>
                    <label className="block text-sm text-gray-400 mb-1">End Time</label>
                    <input
                      type="time"
                      value={settings.nightModeEnd}
                      onChange={(e) => updateSetting('nightModeEnd', e.target.value)}
                      className="px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white focus:outline-none focus:border-blue-500"
                    />
                  </div>
                </div>
              )}
            </div>
          </section>

          {/* Privacy Section */}
          <section className="bg-gray-800 rounded-lg p-6">
            <h2 className="text-lg font-semibold text-white mb-4">Privacy</h2>
            <p className="text-gray-400 text-sm mb-4">
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
          <section className="bg-gray-800 rounded-lg p-6">
            <h2 className="text-lg font-semibold text-white mb-4">Notifications</h2>
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
          <section className="bg-gray-800 rounded-lg p-6">
            <h2 className="text-lg font-semibold text-white mb-4">Data</h2>
            <div className="space-y-4">
              <button className="w-full py-3 bg-gray-700 text-white rounded-lg hover:bg-gray-600 transition-colors text-left px-4 flex items-center justify-between">
                <span>Export Your Data</span>
                <svg className="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                </svg>
              </button>
              <button className="w-full py-3 bg-red-600/20 text-red-400 rounded-lg hover:bg-red-600/30 transition-colors text-left px-4 flex items-center justify-between">
                <span>Clear All Learned Data</span>
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </button>
            </div>
          </section>

          {/* Save Button */}
          <div className="flex justify-end">
            <button
              onClick={saveSettings}
              disabled={saving}
              className={`px-6 py-3 rounded-lg font-medium transition-colors ${
                saved
                  ? 'bg-green-600 text-white'
                  : 'bg-blue-600 text-white hover:bg-blue-700'
              } disabled:opacity-50`}
            >
              {saving ? 'Saving...' : saved ? 'Saved!' : 'Save Changes'}
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
        <p className="text-white">{label}</p>
        <p className="text-gray-400 text-sm">{description}</p>
      </div>
      <button
        onClick={() => onChange(!checked)}
        className={`relative w-12 h-6 rounded-full transition-colors ${
          checked ? 'bg-blue-600' : 'bg-gray-600'
        }`}
      >
        <span
          className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-transform ${
            checked ? 'left-7' : 'left-1'
          }`}
        />
      </button>
    </div>
  );
}
