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
