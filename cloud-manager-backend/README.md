# Cloud Manager Backend

A comprehensive Go backend for managing, controlling, and monitoring cloud services across Google Cloud Platform (GCP), Amazon Web Services (AWS), and Microsoft Azure.

## 🚀 Features

### Multi-Cloud Support
- **AWS**: EC2, S3, RDS, EKS, Lambda, CloudWatch, IAM
- **GCP**: Compute Engine, Cloud Storage, Cloud SQL, GKE, Cloud Monitoring
- **Azure**: Virtual Machines, Storage Accounts, AKS, VNets, Load Balancers

### Core Features
- **Resource Management**: Full lifecycle management (create, start, stop, terminate)
- **Monitoring**: Real-time metrics, dashboards, and health checks
- **Alerting**: Configurable alerts with multiple notification channels
- **Cost Management**: Cost analysis and forecasting
- **Audit Logging**: Complete audit trail for all operations

### Notifications
- Email (SMTP)
- Telegram Bot
- Slack (Bot & Webhook)

### Security
- JWT-based authentication
- Role-based access control
- Rate limiting
- Request logging and audit trails

## 📋 Prerequisites

- Go 1.22+
- PostgreSQL 16+
- Docker & Docker Compose (optional)
- Cloud provider credentials (AWS/GCP/Azure)

## 🛠️ Installation

### Clone Repository
```bash
git clone https://github.com/yourusername/cloud-manager-backend.git
cd cloud-manager-backend
```

### Install Dependencies
```bash
go mod download
```

### Configure Environment
```bash
cp .env.example .env
# Edit .env with your configuration
```

### Run Migrations
```bash
make migrate-up
```

### Start Server
```bash
# Development with hot reload
make dev

# Production build
make build
./bin/cloud-manager
```

## 🐳 Docker

### Quick Start
```bash
docker-compose up -d
```

### Development
```bash
docker-compose -f docker-compose.dev.yml up -d
```

### Services
| Service | Port | Description |
|---------|------|-------------|
| API | 8080 | Main application |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache (optional) |
| pgAdmin | 5050 | Database management |
| MailHog | 8025 | Email testing (dev) |

## 📚 API Documentation

### Base URL
```
http://localhost:8080/api/v1
```

### Authentication
All protected endpoints require a Bearer token:
```
Authorization: Bearer <your_jwt_token>
```

### Endpoints

#### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/register` | Register a new user |
| POST | `/auth/login` | Login and get tokens |
| POST | `/auth/refresh` | Refresh access token |
| POST | `/auth/logout` | Logout |
| GET | `/auth/profile` | Get user profile |
| PUT | `/auth/password` | Change password |

#### Cloud Providers
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/providers` | List all providers |
| POST | `/providers` | Add a provider |
| GET | `/providers/:id` | Get provider details |
| PUT | `/providers/:id` | Update provider |
| DELETE | `/providers/:id` | Remove provider |
| POST | `/providers/:id/test` | Test connection |
| POST | `/providers/:id/sync` | Sync resources |

#### Compute (EC2/VM/Compute Engine)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/compute/instances` | List instances |
| POST | `/compute/instances` | Create instance |
| GET | `/compute/instances/:id` | Get instance |
| POST | `/compute/instances/:id/start` | Start instance |
| POST | `/compute/instances/:id/stop` | Stop instance |
| POST | `/compute/instances/:id/reboot` | Reboot instance |
| DELETE | `/compute/instances/:id` | Terminate instance |
| GET | `/compute/instances/:id/metrics` | Get metrics |

#### Storage (S3/GCS/Blob)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/storage/buckets` | List buckets |
| POST | `/storage/buckets` | Create bucket |
| DELETE | `/storage/buckets/:name` | Delete bucket |
| GET | `/storage/buckets/:name/objects` | List objects |
| POST | `/storage/buckets/:name/objects` | Upload object |
| GET | `/storage/buckets/:name/objects/*key` | Download object |
| DELETE | `/storage/buckets/:name/objects/*key` | Delete object |

#### Databases (RDS/Cloud SQL/Azure SQL)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/databases` | List databases |
| POST | `/databases` | Create database |
| GET | `/databases/:id` | Get database |
| POST | `/databases/:id/start` | Start database |
| POST | `/databases/:id/stop` | Stop database |
| POST | `/databases/:id/snapshot` | Create snapshot |

#### Kubernetes (EKS/GKE/AKS)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/kubernetes/clusters` | List clusters |
| POST | `/kubernetes/clusters` | Create cluster |
| GET | `/kubernetes/clusters/:id` | Get cluster |
| DELETE | `/kubernetes/clusters/:id` | Delete cluster |
| POST | `/kubernetes/clusters/:id/scale` | Scale cluster |
| GET | `/kubernetes/clusters/:id/kubeconfig` | Get kubeconfig |

#### Alerts
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/alerts` | List alerts |
| POST | `/alerts` | Create alert |
| PUT | `/alerts/:id` | Update alert |
| DELETE | `/alerts/:id` | Delete alert |
| POST | `/alerts/:id/enable` | Enable alert |
| POST | `/alerts/:id/disable` | Disable alert |
| POST | `/alerts/:id/test` | Test alert |

#### Monitoring
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/monitoring/metrics` | Get metrics |
| GET | `/monitoring/dashboard` | Dashboard stats |
| GET | `/monitoring/costs` | Cost analysis |
| GET | `/monitoring/health` | Resource health |
| GET | `/monitoring/audit-logs` | Audit logs |

## 🏗️ Project Structure

```
cloud-manager-backend/
├── cmd/
│   └── server/
│       └── main.go          # Application entry point
├── config/
│   └── config.yaml          # Default configuration
├── internal/
│   ├── app/
│   │   └── app.go           # DI container and modules
│   ├── cloud/
│   │   ├── interface.go     # Cloud provider interface
│   │   ├── aws_provider.go  # AWS implementation
│   │   ├── gcp_provider.go  # GCP implementation
│   │   ├── azure_provider.go# Azure implementation
│   │   └── provider_factory.go
│   ├── config/
│   │   └── config.go        # Configuration management
│   ├── database/
│   │   ├── database.go      # Database connection
│   │   └── migrate.go       # Migration utilities
│   ├── handlers/
│   │   ├── auth_handler.go
│   │   ├── cloud_provider_handler.go
│   │   ├── compute_handler.go
│   │   └── ...
│   ├── middleware/
│   │   ├── auth_middleware.go
│   │   ├── logging_middleware.go
│   │   └── rate_limiter.go
│   ├── models/
│   │   └── models.go        # Domain models
│   ├── notification/
│   │   ├── notification.go
│   │   ├── email.go
│   │   ├── telegram.go
│   │   └── slack.go
│   ├── repository/
│   │   ├── user_repository.go
│   │   ├── cloud_provider_repository.go
│   │   └── ...
│   ├── routes/
│   │   └── routes.go        # API routes
│   └── service/
│       ├── auth_service.go
│       ├── cloud_provider_service.go
│       └── ...
├── migrations/
│   ├── 000001_init_schema.up.sql
│   └── 000001_init_schema.down.sql
├── docker-compose.yml
├── docker-compose.dev.yml
├── Dockerfile
├── Dockerfile.dev
├── Makefile
├── go.mod
└── go.sum
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVER_HOST` | Server host | `0.0.0.0` |
| `SERVER_PORT` | Server port | `8080` |
| `DATABASE_HOST` | PostgreSQL host | `localhost` |
| `DATABASE_PORT` | PostgreSQL port | `5432` |
| `DATABASE_USER` | Database user | `cloudmanager` |
| `DATABASE_PASSWORD` | Database password | - |
| `DATABASE_NAME` | Database name | `cloudmanager` |
| `JWT_SECRET` | JWT signing secret | - |
| `AWS_ACCESS_KEY_ID` | AWS access key | - |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | - |
| `GCP_PROJECT_ID` | GCP project ID | - |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription | - |

See `.env.example` for complete list.

## 🧪 Testing

```bash
# Run all tests
make test

# Run with coverage
make test-coverage
```

## 📝 Development

### Install Tools
```bash
make install-tools
```

### Code Formatting
```bash
make fmt
```

### Linting
```bash
make lint
```

### Generate Swagger Docs
```bash
make swagger
```

## 🔒 Security Considerations

1. **Credentials**: Never commit credentials. Use environment variables or secrets management.
2. **JWT Secrets**: Use strong, unique secrets in production.
3. **Database**: Use SSL in production, implement proper password policies.
4. **Rate Limiting**: Configure appropriate limits for your use case.
5. **HTTPS**: Always use HTTPS in production.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
