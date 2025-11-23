/**
 * Activity Log Page - Shows all recorded user actions
 */

import { useState, useEffect } from 'react';
import axios from 'axios';
import Layout from '../components/Layout';

export default function ActivityPage({ user }) {
  const [activity, setActivity] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);

  useEffect(() => {
    loadActivity();
  }, [filter]);

  const loadActivity = async (loadMore = false) => {
    try {
      const currentPage = loadMore ? page + 1 : 1;
      const response = await axios.get('/api/cloe/activity', {
        params: {
          limit: 50,
          page: currentPage,
          type: filter !== 'all' ? filter : undefined
        }
      });

      if (loadMore) {
        setActivity([...activity, ...response.data.activity]);
      } else {
        setActivity(response.data.activity);
      }
      setHasMore(response.data.hasMore);
      setPage(currentPage);
    } catch (error) {
      console.error('Failed to load activity:', error);
    } finally {
      setLoading(false);
    }
  };

  const actionTypes = [
    { value: 'all', label: 'All Activity' },
    { value: 'openApp', label: 'App Opens' },
    { value: 'switchApp', label: 'App Switches' },
    { value: 'openFile', label: 'File Opens' },
    { value: 'saveFile', label: 'File Saves' },
    { value: 'copyText', label: 'Copy/Paste' },
    { value: 'sendEmail', label: 'Emails' },
    { value: 'openURL', label: 'URLs' },
    { value: 'search', label: 'Searches' },
  ];

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

  const actionColors = {
    openApp: 'bg-green-600',
    closeApp: 'bg-red-600',
    switchApp: 'bg-blue-600',
    openFile: 'bg-yellow-600',
    saveFile: 'bg-yellow-600',
    copyText: 'bg-purple-600',
    pasteText: 'bg-purple-600',
    sendEmail: 'bg-pink-600',
    openURL: 'bg-cyan-600',
    search: 'bg-orange-600'
  };

  const formatTime = (timestamp) => {
    const date = new Date(timestamp);
    return date.toLocaleString();
  };

  const groupByDate = (items) => {
    const groups = {};
    items.forEach(item => {
      const date = new Date(item.timestamp).toLocaleDateString();
      if (!groups[date]) {
        groups[date] = [];
      }
      groups[date].push(item);
    });
    return groups;
  };

  const groupedActivity = groupByDate(activity);

  return (
    <Layout user={user}>
      <div className="p-8">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold text-white mb-2">Activity Log</h1>
            <p className="text-gray-400">All actions recorded by Cloe</p>
          </div>

          {/* Filter */}
          <select
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white focus:outline-none focus:border-blue-500"
          >
            {actionTypes.map(type => (
              <option key={type.value} value={type.value}>{type.label}</option>
            ))}
          </select>
        </div>

        {/* Activity List */}
        {loading ? (
          <div className="flex items-center justify-center py-16">
            <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500"></div>
          </div>
        ) : activity.length > 0 ? (
          <div className="space-y-8">
            {Object.entries(groupedActivity).map(([date, items]) => (
              <div key={date}>
                <h2 className="text-sm font-medium text-gray-400 mb-4 sticky top-0 bg-gray-900 py-2">
                  {date === new Date().toLocaleDateString() ? 'Today' : date}
                </h2>
                <div className="space-y-2">
                  {items.map((item, index) => (
                    <div
                      key={item.id || index}
                      className="flex items-center gap-4 p-4 bg-gray-800 rounded-lg hover:bg-gray-750 transition-colors"
                    >
                      <div className={`w-10 h-10 ${actionColors[item.type] || 'bg-gray-600'} rounded-lg flex items-center justify-center flex-shrink-0`}>
                        <ActionIcon type={item.type} />
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-white font-medium">
                          {actionLabels[item.type] || item.type} <span className="text-blue-400">{item.app}</span>
                        </p>
                        {item.target && (
                          <p className="text-gray-400 text-sm truncate">{item.target}</p>
                        )}
                        {item.value && (
                          <p className="text-gray-500 text-xs truncate mt-1">{item.value}</p>
                        )}
                      </div>
                      <span className="text-gray-500 text-sm whitespace-nowrap">
                        {new Date(item.timestamp).toLocaleTimeString()}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            ))}

            {/* Load More */}
            {hasMore && (
              <div className="text-center pt-4">
                <button
                  onClick={() => loadActivity(true)}
                  className="px-6 py-2 bg-gray-700 text-white rounded-lg hover:bg-gray-600 transition-colors"
                >
                  Load More
                </button>
              </div>
            )}
          </div>
        ) : (
          <div className="text-center py-16">
            <svg className="w-16 h-16 text-gray-600 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
            </svg>
            <p className="text-gray-400 text-lg">No activity recorded yet</p>
            <p className="text-gray-500 mt-2">Start using your Mac with Cloe running to see your activity here</p>
          </div>
        )}
      </div>
    </Layout>
  );
}

function ActionIcon({ type }) {
  const icons = {
    openApp: <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6z" />,
    closeApp: <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />,
    switchApp: <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />,
    openFile: <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />,
    saveFile: <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />,
    copyText: <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />,
    pasteText: <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />,
    sendEmail: <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />,
    openURL: <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />,
    search: <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
  };

  return (
    <svg className="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      {icons[type] || <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />}
    </svg>
  );
}
