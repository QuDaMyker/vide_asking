# DevOps Interview Questions (Junior & Middle)

## 1. Infrastructure as Code (Junior)

**Question:** Why is infrastructure as code important?

**Answer:** Infrastructure as code (IaC) tools like Terraform or CloudFormation describe environments declaratively, enabling version control, repeatable deployments, automated testing, and rollback. They eliminate snowflake servers and minimize configuration drift.

**Example:**

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "company-logs"
  acl    = "private"
  versioning {
    enabled = true
  }
}
```

A Terraform snippet provisions an S3 bucket consistently across environments.

## 2. CI/CD Value (Junior)

**Question:** What does CI/CD provide?

**Answer:** Continuous Integration compiles, tests, and validates every change automatically, while Continuous Delivery/Deployment promotes approved artifacts to staging or production. Together they shorten feedback loops, reduce manual errors, and improve release confidence.

**Example:**

```yaml
name: backend-ci
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm test
```

A GitHub Actions pipeline enforces automated builds and tests on every push.

## 3. Blue-Green Deployments (Middle)

**Question:** How do you implement blue-green deployment?

**Answer:** Maintain two identical environments. Deploy the new version to the inactive color, run tests, then switch traffic via load balancer or DNS. Keep the old color ready for instant rollback if issues appear.

**Example:**

```text
Production load balancer points to the blue ECS service. A new release is deployed to the green ECS service, smoke tests pass, then the load balancer target group shifts to green. Blue remains running for rapid rollback.
```

The strategy reduces downtime and mitigates release risk.

## 4. Monitoring and Auto-Scaling (Middle)

**Question:** How do you monitor and auto-scale services under high concurrency?

**Answer:** Collect metrics (CPU, memory, latency, queue depth), set SLO-driven alerts, and configure auto-scaling policies that add instances when thresholds exceed (e.g., 70% CPU) and scale in cautiously. Combine health probes, graceful shutdown, and warm-up to avoid thrashing.

**Example:**

```yaml
autoscaling:
  targetCPUUtilizationPercentage: 70
  minReplicas: 3
  maxReplicas: 20
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        averageUtilization: 70
```

A Kubernetes HorizontalPodAutoscaler monitors CPU and scales pods within defined bounds.

## 5. Secrets Management (Junior)

**Question:** How should teams manage application secrets?

**Answer:** Store secrets in dedicated vaults (AWS Secrets Manager, HashiCorp Vault, Kubernetes Secrets with envelope encryption), enforce least privilege access, audit retrieval, and rotate credentials regularly instead of baking them into images or code.

**Example:**

```text
Deployments mount an external secrets volume populated by Vault Agent. The agent refreshes database credentials automatically, and pods read them from tmpfs rather than environment variables checked into Git.
```

This limits blast radius if a container is compromised.

## 6. Container Image Best Practices (Junior)

**Question:** What are best practices for building container images?

**Answer:** Use minimal base images, run as non-root, copy only required artifacts, pin versions, and leverage multi-stage builds to shrink size. Regularly scan images for vulnerabilities.

**Example:**

```dockerfile
FROM golang:1.23 AS build
WORKDIR /src
COPY . .
RUN go build -o app ./cmd/server

FROM gcr.io/distroless/base-debian12
COPY --from=build /src/app /app
USER nonroot
ENTRYPOINT ["/app"]
```

The resulting image excludes compilers and runs with the least privilege needed.

## 7. Observability Stack (Middle)

**Question:** How do you assemble an observability stack for production?

**Answer:** Combine metrics collection (Prometheus), logging (ELK, Loki), tracing (Jaeger, Tempo), and alerting (Alertmanager, PagerDuty). Automate dashboards and define SLOs that link telemetry to customer impact.

**Example:**

```text
Terraform provisions Prometheus and Grafana, Fluent Bit forwards structured logs to Loki, and OpenTelemetry collectors export traces to Jaeger. Alertmanager routes SLO breaches to Slack and on-call rotations.
```

Unified tooling accelerates triage during incidents.

## 8. Disaster Recovery Planning (Middle)

**Question:** What does a robust disaster recovery plan include?

**Answer:** Define Recovery Time Objective (RTO) and Recovery Point Objective (RPO), automate backups with verification, rehearse failover playbooks, and maintain infrastructure templates to recreate environments quickly in secondary regions.

**Example:**

```text
Nightly backups stream to an offsite bucket with integrity checks. Quarterly game days restore the database to a warm standby region and promote it within 15 minutes, meeting the 30-minute RTO target.
```

Regular drills validate recovery assumptions before real outages.

## 9. Security Scanning in CI (Middle)

**Question:** How do you integrate security scanning into pipelines?

**Answer:** Add stages for dependency scanning (OWASP Dependency-Check, Snyk), image scanning (Trivy), and static analysis (Semgrep). Fail builds on critical findings and track remediation SLAs.

**Example:**

```yaml
jobs:
  security:
    uses: company/security-action@v2
    with:
      scan-images: true
      scan-dependencies: true
```

Pipelines surface vulnerabilities before deployment, reducing risk exposure.

## 10. Canary Releases (Middle)

**Question:** How do canary releases differ from blue-green?

**Answer:** Canaries shift a small percentage of traffic to the new version, monitor key metrics, and gradually increase exposure. Unlike blue-green's full cutover, canaries provide finer control and early rollback when anomalies appear.

**Example:**

```text
Service mesh routing sends 5% of requests to v2 while monitoring error rate and latency. If metrics stay within SLO for 30 minutes, traffic ramps to 50%, then 100%; otherwise, traffic reverts to v1 automatically.
```

This staged rollout limits blast radius from regressions.
