import React from 'react';

export const App: React.FC = () => {
  return (
    <div style={{ padding: '2rem', fontFamily: 'sans-serif', backgroundColor: '#0f172a', color: '#f8fafc', minHeight: '100vh' }}>
      <header style={{ borderBottom: '1px solid #334155', paddingBottom: '1rem', marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700, color: '#38bdf8' }}>
          SentinelOps — SOC Command & Automated Response Lab
        </h1>
        <p style={{ color: '#94a3b8', fontSize: '0.9rem' }}>
          Real-time Detection Engineering, MITRE ATT&CK Triage, and Controlled Playbooks
        </p>
      </header>
      <main>
        <div style={{ backgroundColor: '#1e293b', padding: '1.5rem', borderRadius: '8px', border: '1px solid #334155' }}>
          <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem', color: '#f1f5f9' }}>System Status</h2>
          <p style={{ color: '#cbd5e1' }}>
            SOC Management Network: <span style={{ color: '#4ade80' }}>192.168.56.0/24</span> | Lab Subnet: <span style={{ color: '#4ade80' }}>172.28.0.0/24</span>
          </p>
          <p style={{ color: '#94a3b8', marginTop: '0.5rem', fontSize: '0.85rem' }}>
            Connected to VirtualBox Environment. Ready for Phase 02 Infrastructure Deployment.
          </p>
        </div>
      </main>
    </div>
  );
};

export default App;

