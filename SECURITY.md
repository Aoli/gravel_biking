# Security Policy for Gravel First

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in Gravel First, please report it responsibly:

### How to Report

1. **Email**: Send details to [your-security-email]
2. **Subject**: "Security Vulnerability - Gravel First"
3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Assessment**: Within 1 week
- **Fix & Release**: Within 2-4 weeks (depending on severity)

### Security Measures

This project implements the following security practices:

#### Development Security

- Static code analysis with dart_code_metrics
- Dependency vulnerability scanning
- Automated security testing in CI/CD
- Code review requirements for all changes

#### Runtime Security

- HTTPS-only network communications
- Secure data storage with Hive encryption
- Input validation and sanitization
- Proper permission handling (location services)

#### Data Protection

- No personal data collection beyond location (with permission)
- Local data storage only (no server-side storage)
- Transparent data usage in app

### Security Features

- **Local-First**: All data stored locally on device
- **Encrypted Storage**: Route data encrypted using Hive
- **Secure APIs**: Only communicates with trusted OpenStreetMap services
- **Minimal Permissions**: Only requests necessary permissions
- **No Tracking**: No analytics or tracking beyond crash reporting

### Third-Party Dependencies

We regularly audit our dependencies for security vulnerabilities:

- Flutter framework and dart:* packages (Google-maintained)
- OpenStreetMap Overpass API (read-only access)
- Material Design icons (static assets)
- File system access (permission-based)

### Security Updates

Security patches will be released as soon as possible and communicated through:

- GitHub security advisories
- Release notes
- App store updates

### Responsible Disclosure

We appreciate security researchers who responsibly disclose vulnerabilities. We commit to:

- Acknowledge receipt of your report
- Keep you informed of our progress
- Credit you in release notes (unless you prefer otherwise)
- Work with you to ensure proper disclosure timing

Thank you for helping keep Gravel First secure!
