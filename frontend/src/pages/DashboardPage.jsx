/**
 * Dashboard Overview Page - Cloe AI
 * Monochrome Design: black, white, gray only
 */

import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import Layout from '../components/Layout';

export default function DashboardPage({ user }) {
  const [stats, setStats] = useState({
    actions: 0,
    contacts: 0,
    workflows: 0,
    apps: 0
  });
  const [recentActivity, setRecentActivity] = useState([]);
  const [loading, setLoading] = useState(true);
  const [connectionStatus, setConnectionStatus] = useState('disconnected');

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      const [statsRes, activityRes] = await Promise.all([
        axios.get('/api/cloe/stats'),
        axios.get('/api/cloe/activity?limit=5')
      ]);
      setStats(statsRes.data.stats);
      setRecentActivity(activityRes.data.activity);
      setConnectionStatus(statsRes.data.connected ? 'connected' : 'disconnected');
    } catch (error) {
      console.error('Failed to load dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Layout user={user}>
      <div className="p-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold mb-2" style={{ color: '#fafafa' }}>
            Welcome back, {user?.name?.split(' ')[0] || 'User'}
          </h1>
          <p style={{ color: '#737373' }}>Here's what Cloe has been learning</p>
        </div>

        {/* Connection Status */}
        <div
          className="mb-8 p-4 rounded-lg flex items-center gap-3 border"
          style={{
            backgroundColor: '#1a1a1a',
            borderColor: connectionStatus === 'connected' ? '#525252' : '#525252'
          }}
        >
          <div
            className="w-2 h-2 rounded-full"
            style={{ backgroundColor: connectionStatus === 'connected' ? '#a3a3a3' : '#525252' }}
          />
          <span style={{ color: '#a3a3a3' }}>
            {connectionStatus === 'connected'
              ? 'Cloe desktop app is connected and syncing'
              : 'Cloe desktop app not connected - make sure it\'s running'
            }
          </span>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <StatCard title="Actions Recorded" value={stats.actions} />
          <StatCard title="Contacts Learned" value={stats.contacts} />
          <StatCard title="Workflows Created" value={stats.workflows} />
          <StatCard title="Apps Tracked" value={stats.apps} />
        </div>

        {/* Content Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Recent Activity */}
          <div className="rounded-lg p-6" style={{ backgroundColor: '#1a1a1a' }}>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold" style={{ color: '#fafafa' }}>Recent Activity</h2>
              <Link to="/activity" className="text-sm" style={{ color: '#737373' }}>
                View all
              </Link>
            </div>

            {loading ? (
              <div className="flex items-center justify-center py-8">
                <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2" style={{ borderColor: '#525252' }}></div>
              </div>
            ) : recentActivity.length > 0 ? (
              <div className="space-y-3">
                {recentActivity.map((activity, index) => (
                  <ActivityItem key={index} activity={activity} />
                ))}
              </div>
            ) : (
              <div className="text-center py-8">
                <svg className="w-12 h-12 mx-auto mb-3" style={{ color: '#525252' }} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
                <p style={{ color: '#737373' }}>No activity recorded yet</p>
                <p className="text-sm mt-1" style={{ color: '#525252' }}>Start using your Mac with Cloe running</p>
              </div>
            )}
          </div>

          {/* Quick Actions */}
          <div className="rounded-lg p-6" style={{ backgroundColor: '#1a1a1a' }}>
            <h2 className="text-xl font-semibold mb-4" style={{ color: '#fafafa' }}>Quick Actions</h2>

            <div className="space-y-3">
              <Link
                to="/contacts"
                className="flex items-center gap-4 p-4 rounded-lg transition-colors"
                style={{ backgroundColor: '#262626' }}
              >
                <div className="w-10 h-10 rounded-lg flex items-center justify-center" style={{ backgroundColor: '#1a1a1a' }}>
                  <svg className="w-5 h-5" style={{ color: '#a3a3a3' }} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                </div>
                <div>
                  <p className="font-medium" style={{ color: '#fafafa' }}>Manage Contacts</p>
                  <p className="text-sm" style={{ color: '#525252' }}>View and edit learned contacts</p>
                </div>
              </Link>

              <Link
                to="/workflows"
                className="flex items-center gap-4 p-4 rounded-lg transition-colors"
                style={{ backgroundColor: '#262626' }}
              >
                <div className="w-10 h-10 rounded-lg flex items-center justify-center" style={{ backgroundColor: '#1a1a1a' }}>
                  <svg className="w-5 h-5" style={{ color: '#a3a3a3' }} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" />
                  </svg>
                </div>
                <div>
                  <p className="font-medium" style={{ color: '#fafafa' }}>View Workflows</p>
                  <p className="text-sm" style={{ color: '#525252' }}>See your automated workflows</p>
                </div>
              </Link>

              <Link
                to="/settings"
                className="flex items-center gap-4 p-4 rounded-lg transition-colors"
                style={{ backgroundColor: '#262626' }}
              >
                <div className="w-10 h-10 rounded-lg flex items-center justify-center" style={{ backgroundColor: '#1a1a1a' }}>
                  <svg className="w-5 h-5" style={{ color: '#a3a3a3' }} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                </div>
                <div>
                  <p className="font-medium" style={{ color: '#fafafa' }}>Settings</p>
                  <p className="text-sm" style={{ color: '#525252' }}>Configure Cloe preferences</p>
                </div>
              </Link>
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
}

function StatCard({ title, value }) {
  return (
    <div className="rounded-lg p-6" style={{ backgroundColor: '#1a1a1a' }}>
      <div className="flex items-center gap-4">
        <div className="w-12 h-12 rounded-lg flex items-center justify-center" style={{ backgroundColor: '#262626' }}>
          <svg className="w-6 h-6" style={{ color: '#a3a3a3' }} fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
          </svg>
        </div>
        <div>
          <p className="text-sm" style={{ color: '#737373' }}>{title}</p>
          <p className="text-2xl font-bold" style={{ color: '#fafafa' }}>{value}</p>
        </div>
      </div>
    </div>
  );
}

function ActivityItem({ activity }) {
  const actionLabels = {
    openApp: 'Opened',
    closeApp: 'Closed',
    switchApp: 'Switched to',
    openFile: 'Opened file',
    saveFile: 'Saved file',
    copyText: 'Copied text',
    pasteText: 'Pasted text',
    sendEmail: 'Sent email',
    openURL: 'Opened URL',
    search: 'Searched'
  };

  const formatTime = (timestamp) => {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now - date;

    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
    return date.toLocaleDateString();
  };

  return (
    <div className="flex items-center gap-3 p-3 rounded-lg" style={{ backgroundColor: '#262626' }}>
      <div className="w-8 h-8 rounded-lg flex items-center justify-center" style={{ backgroundColor: '#1a1a1a' }}>
        <svg className="w-4 h-4" style={{ color: '#737373' }} fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M13 10V3L4 14h7v7l9-11h-7z" />
        </svg>
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm truncate" style={{ color: '#fafafa' }}>
          {actionLabels[activity.type] || activity.type} {activity.app}
        </p>
        {activity.target && (
          <p className="text-xs truncate" style={{ color: '#525252' }}>{activity.target}</p>
        )}
      </div>
      <span className="text-xs whitespace-nowrap" style={{ color: '#525252' }}>
        {formatTime(activity.timestamp)}
      </span>
    </div>
  );
}
