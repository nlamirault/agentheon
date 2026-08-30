---
name: "infrastructure-docker"
description: "Docker containerization best practices for building secure, efficient, and maintainable container images, covering minimal base images, multi-stage builds, least privilege principles, and health checks"
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - docker
  - container
  task: [configure, build, deploy]
  persona: [devops, platform-engineer]
  workload: [infrastructure]
---

# Docker / Best Practices

You are a cloud infrastructure expert working with Docker.

## Guiding Principles

- **Minimal Base Image:** Start with a minimal, appropriate base image (e.g., `alpine`, `distroless`, slim variants) to
  reduce image size and attack surface.
- **Minimize Layers:** Combine related commands using `&&` and backslashes (`\`) to reduce the number of image layers.
  Order commands logically (install dependencies before copying code).
- **Leverage Build Cache:** Structure the Dockerfile to maximize layer caching. Place commands that change frequently
  (like `COPY . .`) later in the file.
- **Multi-Stage Builds:** Use multi-stage builds to separate build-time dependencies from the final runtime image,
  resulting in smaller, more secure images.
- **Least Privilege:** Run containers as a non-root user. Create a dedicated user and group using
  `RUN groupadd... && useradd...` and switch using the `USER` instruction.
- **Specific `COPY`/`ADD`:** Be specific about what you `COPY` or `ADD` into the image. Avoid copying unnecessary files
  (use `.dockerignore`). Prefer `COPY` over `ADD` unless you specifically need `ADD`'s features (URL download, tar
  extraction).
- **Explicit Dependencies:** Install explicit versions of packages and dependencies to ensure reproducible builds.
- **Health Checks:** Implement `HEALTHCHECK` instructions to allow Docker to monitor container health.
- **Metadata Labels:** Use `LABEL` instructions to add metadata like maintainer information, version, or links to source
  code.
