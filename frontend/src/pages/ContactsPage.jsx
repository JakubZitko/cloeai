/**
 * Contacts Page - Shows learned contacts
 * Monochrome Design: black, white, gray only
 */

import { useState, useEffect } from 'react';
import axios from 'axios';
import Layout from '../components/Layout';

export default function ContactsPage({ user }) {
  const [contacts, setContacts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedContact, setSelectedContact] = useState(null);

  useEffect(() => {
    loadContacts();
  }, []);

  const loadContacts = async () => {
    try {
      const response = await axios.get('/api/cloe/contacts');
      setContacts(response.data.contacts);
    } catch (error) {
      console.error('Failed to load contacts:', error);
    } finally {
      setLoading(false);
    }
  };

  const filteredContacts = contacts.filter(contact =>
    contact.name.toLowerCase().includes(search.toLowerCase()) ||
    contact.email?.toLowerCase().includes(search.toLowerCase()) ||
    contact.relationship?.toLowerCase().includes(search.toLowerCase()) ||
    contact.aliases?.some(alias => alias.toLowerCase().includes(search.toLowerCase()))
  );

  const deleteContact = async (contactId) => {
    if (!confirm('Are you sure you want to delete this contact?')) return;

    try {
      await axios.delete(`/api/cloe/contacts/${contactId}`);
      setContacts(contacts.filter(c => c.id !== contactId));
      setSelectedContact(null);
    } catch (error) {
      console.error('Failed to delete contact:', error);
    }
  };

  return (
    <Layout user={user}>
      <div className="p-8">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold mb-2" style={{ color: '#fafafa' }}>Contacts</h1>
            <p style={{ color: '#737373' }}>People Cloe has learned about from your usage</p>
          </div>
        </div>

        {/* Search */}
        <div className="mb-6">
          <div className="relative">
            <svg className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5" style={{ color: '#525252' }} fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search contacts..."
              className="w-full pl-12 pr-4 py-3 rounded-lg focus:outline-none"
              style={{ backgroundColor: '#1a1a1a', color: '#fafafa', border: '1px solid #262626' }}
            />
          </div>
        </div>

        <div className="flex gap-8">
          {/* Contact List */}
          <div className="flex-1">
            {loading ? (
              <div className="flex items-center justify-center py-16">
                <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2" style={{ borderColor: '#525252' }}></div>
              </div>
            ) : filteredContacts.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {filteredContacts.map(contact => (
                  <div
                    key={contact.id}
                    onClick={() => setSelectedContact(contact)}
                    className="p-4 rounded-lg cursor-pointer transition-colors"
                    style={{
                      backgroundColor: '#1a1a1a',
                      border: selectedContact?.id === contact.id ? '1px solid #525252' : '1px solid transparent'
                    }}
                  >
                    <div className="flex items-center gap-4">
                      <div className="w-12 h-12 rounded-full flex items-center justify-center flex-shrink-0" style={{ backgroundColor: '#262626' }}>
                        <span className="text-lg font-medium" style={{ color: '#a3a3a3' }}>
                          {contact.name.charAt(0).toUpperCase()}
                        </span>
                      </div>
                      <div className="min-w-0">
                        <p className="font-medium truncate" style={{ color: '#fafafa' }}>{contact.name}</p>
                        {contact.relationship && (
                          <p className="text-sm" style={{ color: '#737373' }}>{contact.relationship}</p>
                        )}
                        {contact.email && (
                          <p className="text-sm truncate" style={{ color: '#525252' }}>{contact.email}</p>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-16">
                <svg className="w-16 h-16 mx-auto mb-4" style={{ color: '#525252' }} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
                <p className="text-lg" style={{ color: '#737373' }}>No contacts learned yet</p>
                <p className="mt-2" style={{ color: '#525252' }}>Cloe will learn contacts from your emails and messages</p>
              </div>
            )}
          </div>

          {/* Contact Detail Panel */}
          {selectedContact && (
            <div className="w-80 rounded-lg p-6 flex-shrink-0" style={{ backgroundColor: '#1a1a1a' }}>
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-lg font-semibold" style={{ color: '#fafafa' }}>Contact Details</h2>
                <button
                  onClick={() => setSelectedContact(null)}
                  style={{ color: '#525252' }}
                >
                  <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              {/* Avatar */}
              <div className="flex justify-center mb-6">
                <div className="w-20 h-20 rounded-full flex items-center justify-center" style={{ backgroundColor: '#262626' }}>
                  <span className="text-2xl font-bold" style={{ color: '#a3a3a3' }}>
                    {selectedContact.name.charAt(0).toUpperCase()}
                  </span>
                </div>
              </div>

              {/* Info */}
              <div className="space-y-4">
                <div>
                  <label className="text-sm" style={{ color: '#525252' }}>Name</label>
                  <p style={{ color: '#fafafa' }}>{selectedContact.name}</p>
                </div>

                {selectedContact.relationship && (
                  <div>
                    <label className="text-sm" style={{ color: '#525252' }}>Relationship</label>
                    <p style={{ color: '#fafafa' }}>{selectedContact.relationship}</p>
                  </div>
                )}

                {selectedContact.email && (
                  <div>
                    <label className="text-sm" style={{ color: '#525252' }}>Email</label>
                    <p style={{ color: '#fafafa' }}>{selectedContact.email}</p>
                  </div>
                )}

                {selectedContact.phone && (
                  <div>
                    <label className="text-sm" style={{ color: '#525252' }}>Phone</label>
                    <p style={{ color: '#fafafa' }}>{selectedContact.phone}</p>
                  </div>
                )}

                {selectedContact.aliases?.length > 0 && (
                  <div>
                    <label className="text-sm" style={{ color: '#525252' }}>Also known as</label>
                    <div className="flex flex-wrap gap-2 mt-1">
                      {selectedContact.aliases.map((alias, i) => (
                        <span key={i} className="px-2 py-1 rounded text-sm" style={{ backgroundColor: '#262626', color: '#a3a3a3' }}>
                          {alias}
                        </span>
                      ))}
                    </div>
                  </div>
                )}

                {selectedContact.locations?.length > 0 && (
                  <div>
                    <label className="text-sm" style={{ color: '#525252' }}>Contacted via</label>
                    <div className="flex flex-wrap gap-2 mt-1">
                      {selectedContact.locations.map((loc, i) => (
                        <span key={i} className="px-2 py-1 rounded text-sm" style={{ backgroundColor: '#262626', color: '#737373' }}>
                          {loc.app}
                        </span>
                      ))}
                    </div>
                  </div>
                )}

                {selectedContact.lastContact && (
                  <div>
                    <label className="text-sm" style={{ color: '#525252' }}>Last Contact</label>
                    <p style={{ color: '#fafafa' }}>
                      {new Date(selectedContact.lastContact).toLocaleDateString()}
                    </p>
                  </div>
                )}
              </div>

              {/* Actions */}
              <div className="mt-6 pt-6 space-y-3" style={{ borderTop: '1px solid #262626' }}>
                <button
                  onClick={() => deleteContact(selectedContact.id)}
                  className="w-full py-2 rounded-lg transition-colors"
                  style={{ backgroundColor: '#262626', color: '#a3a3a3' }}
                >
                  Delete Contact
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </Layout>
  );
}
