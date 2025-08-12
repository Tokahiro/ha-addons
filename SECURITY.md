# Security Policy

## 🔒 Supported Versions

We provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 0.11.x  | ✅ Yes             |
| 0.10.x  | ✅ Yes             |
| < 0.10  | ❌ No              |

## 🚨 Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please follow these steps:

### 🔐 Private Disclosure
**Please do NOT create a public GitHub issue for security vulnerabilities.**

Instead, please report security issues by:

1. **GitHub Security Advisory**: Use the private vulnerability reporting feature (preferred)
2. **GitHub Issue**: Create a private issue with "SECURITY" label if advisory is not available

### 📋 Information to Include

When reporting a vulnerability, please provide:

- **Description**: Clear description of the vulnerability
- **Impact**: What could an attacker accomplish?
- **Reproduction**: Steps to reproduce the issue
- **Affected Versions**: Which versions are affected?
- **Suggested Fix**: If you have ideas for a solution
- **Disclosure Timeline**: Your preferred timeline for public disclosure

### 🕐 Response Timeline

This is a hobby project maintained in spare time. **No guaranteed response times.**

- Responses when time permits
- Community contributions welcomed for urgent issues
- Use at your own risk

**Note**: For critical security issues, community help and contributions are especially welcomed.

### 🎖️ Recognition

Security researchers who responsibly disclose vulnerabilities will be:

- Credited in the security advisory (unless they prefer anonymity)
- Listed in our security hall of fame
- Mentioned in release notes

## 🛡️ Security Measures

### Add-on Security Features

- **Home Assistant Integration**: Uses HA's authentication system
- **Ingress Support**: No external ports exposed by default
- **Container Isolation**: Runs in isolated Docker containers
- **Least Privilege**: Minimal required permissions
- **Input Validation**: User inputs are validated and sanitized

### Best Practices for Users

- **Keep Updated**: Always use the latest version
- **Secure Access**: Use strong Home Assistant passwords
- **Network Security**: Secure your Home Assistant instance
- **Regular Backups**: Backup your configuration and data
- **Monitor Logs**: Review add-on logs for suspicious activity

## 🔍 Security Considerations

### Data Storage
- User data is stored within Home Assistant's secure environment
- Database connections use secure authentication
- No sensitive data is logged or transmitted unnecessarily

### Network Access
- Add-ons use Home Assistant's ingress system by default
- External network access is minimal and documented
- All communications use encrypted channels where possible

### Dependencies
- Base images are regularly updated
- Dependencies are monitored for security vulnerabilities
- Automated security scanning is performed

## 📚 Security Resources

- [Home Assistant Security](https://www.home-assistant.io/docs/security/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [OWASP Container Security](https://owasp.org/www-project-container-security/)

## 🆘 Emergency Response

In case of a critical security issue:

1. **Community Alert**: Post immediate warning on GitHub
2. **Best Effort Response**: Security update as soon as possible (hobby project limitations)
3. **Community Help**: Encourage community contributions for urgent fixes
4. **Documentation**: Update with lessons learned

## 📞 Contact Information

- **GitHub**: [@Tokahiro](https://github.com/Tokahiro) (only contact method)
- **Community**: Home Assistant Discord/Forums (community support)

**Note**: This is a hobby project - no guaranteed response times. Use at your own risk.

---

**Thank you for helping keep our add-ons secure!** 🙏