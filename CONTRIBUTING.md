# Contributing

Contributions, bug reports, and suggestions are welcome.

## Getting Started

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Run validation: `terraform fmt -recursive && terraform validate`
5. Commit: `git commit -m "feat: describe your change"`
6. Open a pull request

## Code Standards

- All Terraform must pass `terraform fmt` and `terraform validate`
- Python must pass `black` and `flake8 --max-line-length=120`
- Resource naming must follow `{tenant_name}-{resource-type}` convention
- Every input variable must have a `description`
- Every output must have a `description`
- Security-sensitive changes must include justification in the PR description

## Reporting Security Issues

Please report security vulnerabilities privately — do not open a public issue. Contact via LinkedIn: [ankita-dixit-8892b8185](https://www.linkedin.com/in/ankita-dixit-8892b8185/).
