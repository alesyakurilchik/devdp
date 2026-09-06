import { useState, useEffect } from 'react'
import './App.css'

type MonitoringTab = 'grafana' | 'prometheus'


interface ApiInfo {
  app: string
  version: string
  environment: string
  total_visits: number
}

const pipelineSteps = [
  { num: 1, name: 'Lint & Type Check' },
  { num: 2, name: 'Unit Tests' },
  { num: 3, name: 'Docker Build' },
  { num: 4, name: 'Push to GHCR' },
  { num: 5, name: 'Deploy' },
]

const techStack = [
  { name: 'React' },
  { name: 'FastAPI' },
  { name: 'Docker' },
  { name: 'GitHub Actions' },
  { name: 'PostgreSQL' },
  { name: 'Caddy' },
  { name: 'Prometheus' },
  { name: 'Grafana' },
]

function App() {
  const [apiInfo, setApiInfo] = useState<ApiInfo | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [monitoringTab, setMonitoringTab] = useState<MonitoringTab>('grafana')

  const apiUrl = import.meta.env.VITE_API_URL || ''
  const grafanaUrl = '/grafana/d/fastapi-backend/fastapi-backend?orgId=1&kiosk'
  const prometheusUrl = '/prometheus/graph?g0.expr=rate(http_requests_total%5B5m%5D)&g0.tab=0&g0.range_input=1h'

  useEffect(() => {
    fetch(`${apiUrl}/api/info`)
      .then((res) => {
        if (!res.ok) throw new Error('API request failed')
        return res.json()
      })
      .then((data) => {
        setApiInfo(data)
        setLoading(false)
      })
      .catch((err) => {
        setError(err.message)
        setLoading(false)
      })
  }, [apiUrl])

  return (
    <div className="app-wrapper">
      <div className="bg-mesh" />

      <div className="container">
        <header>
          <h1>DevOps Pipeline</h1>
          <p className="subtitle">Full-Stack CI/CD Infrastructure</p>
        </header>

        <main>
          <section className="glass-card">
            <div className="card-header">
              <span className="card-icon frontend-icon" />
              <h2>Frontend</h2>
            </div>
            <div className="card-content">
              <div className="status-row">
                <div className="status success">
                  <span className="status-indicator" />
                  <span>Running</span>
                </div>
              </div>
              <p className="description">
                React application with TypeScript, served via Nginx with automatic HTTPS
              </p>
            </div>
          </section>

          <section className="glass-card">
            <div className="card-header">
              <span className="card-icon backend-icon" />
              <h2>Backend API</h2>
            </div>
            <div className="card-content">
              {loading && (
                <div className="status-row">
                  <div className="status loading">
                    <span className="status-indicator" />
                    <span>Connecting...</span>
                  </div>
                </div>
              )}
              {error && (
                <>
                  <div className="status-row">
                    <div className="status error">
                      <span className="status-indicator" />
                      <span>Disconnected</span>
                    </div>
                  </div>
                  <p className="error-message">{error}</p>
                </>
              )}
              {apiInfo && (
                <>
                  <div className="status-row">
                    <div className="status success">
                      <span className="status-indicator" />
                      <span>Connected</span>
                    </div>
                  </div>
                  <div className="info-grid">
                    <div className="info-item">
                      <span className="info-label">Version</span>
                      <span className="info-value">{apiInfo.version}</span>
                    </div>
                    <div className="info-item">
                      <span className="info-label">Environment</span>
                      <span className="info-value">{apiInfo.environment}</span>
                    </div>
                    <div className="info-item">
                      <span className="info-label">Total Visits</span>
                      <span className="info-value">{apiInfo.total_visits.toLocaleString()}</span>
                    </div>
                  </div>
                </>
              )}
            </div>
          </section>

          <section className="glass-card wide">
            <div className="card-header">
              <span className="card-icon pipeline-icon" />
              <h2>CI/CD Pipeline</h2>
            </div>
            <div className="pipeline-steps">
              {pipelineSteps.map((step, index) => (
                <div key={step.num} className="pipeline-step">
                  <div className="step-number">{step.num}</div>
                  <span className="step-name">{step.name}</span>
                  {index < pipelineSteps.length - 1 && <div className="step-connector" />}
                </div>
              ))}
            </div>
          </section>

          <section className="glass-card wide">
            <div className="card-header">
              <span className="card-icon stack-icon" />
              <h2>Tech Stack</h2>
            </div>
            <div className="tech-grid">
              {techStack.map((tech) => (
                <div key={tech.name} className="tech-chip">
                  {tech.name}
                </div>
              ))}
            </div>
          </section>

          <section className="glass-card wide monitoring-section">
            <div className="card-header">
              <span className="card-icon monitoring-icon" />
              <h2>Live Monitoring</h2>
            </div>
            <div className="monitoring-tabs">
              <button
                className={`tab-button ${monitoringTab === 'grafana' ? 'active' : ''}`}
                onClick={() => setMonitoringTab('grafana')}
              >
                Grafana Dashboard
              </button>
              <button
                className={`tab-button ${monitoringTab === 'prometheus' ? 'active' : ''}`}
                onClick={() => setMonitoringTab('prometheus')}
              >
                Prometheus
              </button>
            </div>
            <div className="monitoring-frame-container">
              <iframe
                src={monitoringTab === 'grafana' ? grafanaUrl : prometheusUrl}
                title={monitoringTab === 'grafana' ? 'Grafana Dashboard' : 'Prometheus'}
                className="monitoring-frame"
                frameBorder="0"
              />
            </div>
            <div className="monitoring-links">
              <a
                href="/grafana"
                target="_blank"
                rel="noopener noreferrer"
                className="monitoring-link"
              >
                Open Grafana
              </a>
              <a
                href="/prometheus"
                target="_blank"
                rel="noopener noreferrer"
                className="monitoring-link"
              >
                Open Prometheus
              </a>
            </div>
          </section>
        </main>

        <footer>
          <a
            href="https://github.com/alesyakurilchik/devdp"
            target="_blank"
            rel="noopener noreferrer"
            className="footer-link"
          >
            View on GitHub
          </a>
          <span className="footer-divider" />
          <span className="footer-text">Pedram Nikjooy</span>
        </footer>
      </div>
    </div>
  )
}

export default App
