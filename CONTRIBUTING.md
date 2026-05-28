# Contributing Guidelines

Contributions are welcome! This is a community-maintained fork of the
[Kubernetes ingress-nginx](https://github.com/kubernetes/ingress-nginx) project.

## How to Contribute

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Ensure tests pass (`make test`)
5. Submit a Pull Request

## Code Style

- Go: follow [Effective Go](https://go.dev/doc/effective_go) and run `gofmt`
- Lua: follow existing patterns in `rootfs/`
- Shell scripts: follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

## Pull Request Process

1. Update documentation if needed
2. Add tests for new functionality
3. Ensure all existing tests pass
4. Keep PRs focused — one feature/fix per PR

## Reporting Issues

- Use [GitHub Issues](https://github.com/baranchen/ingress-nginx/issues)
- Include version information (`kubectl exec -n ingress-nginx <pod> -- /nginx-ingress-controller --version`)
- For security issues, see [SECURITY.md](SECURITY.md)

## License

By contributing, you agree that your contributions will be licensed under the
[Apache License 2.0](LICENSE).
