# Contributing to Tokahiro's Home Assistant Add-ons

Thank you for your interest in contributing! This document provides guidelines for contributing to this add-on repository.

## 🚀 Getting Started

### Prerequisites
- Home Assistant development environment
- Docker for building and testing add-ons
- Git for version control
- Basic understanding of YAML, Bash, and Docker

### Development Setup
1. Fork this repository
2. Clone your fork locally
3. Create a new branch for your changes
4. Make your modifications
5. Test thoroughly
6. Submit a pull request

## 📝 Types of Contributions

### 🐛 Bug Reports
When reporting bugs, please include:
- Home Assistant version
- Add-on version
- Detailed steps to reproduce
- Expected vs actual behavior
- Relevant log entries
- System information (architecture, OS)

### 💡 Feature Requests
For new features, please provide:
- Clear description of the feature
- Use case and benefits
- Implementation suggestions (if any)
- Compatibility considerations

### 🔧 Code Contributions
- Follow existing code style and patterns
- Include tests where applicable
- Update documentation for any changes
- Ensure backwards compatibility when possible

## 🛠️ Development Guidelines

### Add-on Structure
```
addon-name/
├── config.yaml          # Add-on configuration
├── Dockerfile           # Container definition
├── run.sh              # Startup script
├── README.md           # Add-on documentation
├── DOCS.md             # Detailed documentation
├── CHANGELOG.md        # Version history
├── icon.png            # Add-on icon (128x128)
└── translations/       # i18n files
    └── en.yaml
```

### Code Style
- **YAML**: Use 2-space indentation, no tabs
- **Bash**: Follow Google Shell Style Guide
- **Docker**: Use multi-stage builds when beneficial
- **Documentation**: Use clear, concise language with examples

### Testing
- Test on multiple architectures when possible
- Verify add-on installs and starts correctly
- Check ingress and external access functionality
- Validate configuration options work as expected
- Test database connectivity and data persistence

## 📋 Pull Request Process

### Before Submitting
1. **Test thoroughly** on your development environment
2. **Update documentation** for any user-facing changes
3. **Update CHANGELOG.md** with your changes
4. **Verify compatibility** with current Home Assistant versions
5. **Check for breaking changes** and document them

### PR Requirements
- Clear, descriptive title
- Detailed description of changes
- Reference any related issues
- Include testing information
- Screenshots for UI changes
- Breaking change notifications

### Review Process
1. Automated checks will run
2. Manual review by maintainers
3. Testing on multiple environments
4. Community feedback period
5. Merge after approval

## 🏷️ Versioning

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features, backwards compatible
- **PATCH**: Bug fixes, backwards compatible

### Version Bumping
When making changes:
1. Update version in `config.yaml`
2. Update version references in documentation
3. Add entry to `CHANGELOG.md`
4. Update startup script version log

## 📚 Documentation Standards

### README Files
- Clear installation instructions
- Feature overview with benefits
- Configuration examples
- Troubleshooting section
- Credits and attributions

### DOCS Files
- Comprehensive setup guide
- Detailed configuration options
- Advanced usage scenarios
- FAQ and troubleshooting
- Integration examples

### Code Comments
- Explain complex logic
- Document configuration options
- Include examples where helpful
- Maintain consistency with existing style

## 🔒 Security Considerations

### Sensitive Information
- Never commit passwords or API keys
- Use Home Assistant secrets when possible
- Validate all user inputs
- Follow principle of least privilege

### Dependencies
- Keep dependencies minimal and current
- Regular security updates
- Scan for known vulnerabilities
- Document security implications

## 🌟 Recognition

Contributors will be:
- Listed in the repository contributors
- Mentioned in release notes for significant contributions
- Credited in documentation for major features

## 📞 Getting Help

- **Questions**: Use GitHub Discussions
- **Bugs**: Create GitHub Issues

**Note**: This is a hobby project maintained in spare time. Use at your own risk. Responses when time permits.

## 📄 License

By contributing, you agree that your contributions will be licensed under the same MIT License that covers the project.

---

**Thank you for helping make these add-ons better for everyone!** 🎉