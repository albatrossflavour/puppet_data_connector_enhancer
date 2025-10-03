# Contributing to Puppet Data Connector Enhancer

Thank you for your interest in contributing to the Puppet Data Connector Enhancer module! This document provides guidelines and instructions for contributing.

## Code of Conduct

Be respectful, professional, and constructive in all interactions. We're all here to make better tools for the Puppet community.

## How to Contribute

### Reporting Bugs

Before creating a bug report:

1. Check the [existing issues](https://github.com/albatrossflavour/puppet-puppet_data_connector_enhancer/issues) to avoid duplicates
2. Collect relevant information (Puppet version, OS, module version, error messages)

When creating a bug report, include:

- Clear, descriptive title
- Steps to reproduce the issue
- Expected behaviour
- Actual behaviour
- Environment details (PE version, OS, module version)
- Relevant logs or error messages
- Puppet code that demonstrates the issue

### Suggesting Enhancements

Enhancement suggestions are welcome! Please:

1. Check existing issues for similar suggestions
2. Provide a clear use case and rationale
3. Describe the desired behaviour
4. Consider backward compatibility implications

### Submitting Pull Requests

1. **Fork and create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow the code standards below
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**
   ```bash
   pdk validate       # Syntax and style checks
   pdk test unit      # Run unit tests
   ```

4. **Commit your changes**
   - Use clear, descriptive commit messages
   - Reference related issues (e.g., "Fixes #123")
   - Use UK spelling in all documentation

5. **Push and create a pull request**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Pull request checklist**
   - [ ] Tests pass (`pdk test unit`)
   - [ ] Code passes validation (`pdk validate`)
   - [ ] Documentation updated (README.md, REFERENCE.md, inline docs)
   - [ ] CHANGELOG.md updated with your changes
   - [ ] Commit messages are clear and descriptive
   - [ ] PR description explains the changes and rationale

## Code Standards

### Puppet Code Style

- Follow the [Puppet style guide](https://puppet.com/docs/puppet/latest/style_guide.html)
- Use [Puppet Strings](https://puppet.com/docs/puppet/latest/puppet_strings.html) for documentation
- Parameter validation using strong types
- Use UK spelling in all documentation and user-facing strings

### Testing Standards

- All new functionality must include RSpec tests
- Maintain or improve test coverage
- Tests should cover:
  - Default parameter behaviour
  - Custom parameter configurations
  - Edge cases and error conditions
  - Resource ordering and dependencies

### Documentation Standards

- Update README.md for user-facing changes
- Use Puppet Strings (`@summary`, `@param`, `@example`) for all classes/functions
- Update REFERENCE.md by running `puppet strings generate --format markdown`
- Follow markdownlint rules (no overrides)
- Use UK spelling consistently

### Ruby Code Standards

- Follow Ruby style guide for custom functions
- Include error handling and logging
- Add comments for complex logic
- Use descriptive variable and method names

## Development Workflow

### Setting Up Development Environment

```bash
# Install PDK
# See: https://puppet.com/docs/pdk/latest/pdk_install.html

# Clone repository
git clone https://github.com/albatrossflavour/puppet-puppet_data_connector_enhancer.git
cd puppet-puppet_data_connector_enhancer

# Install dependencies
pdk bundle install
```

### Running Tests

```bash
# Validate syntax and style
pdk validate

# Run unit tests
pdk test unit

# Run specific test file
pdk test unit --tests=spec/classes/puppet_data_connector_enhancer_spec.rb

# Run with verbose output
pdk test unit --verbose
```

### Building the Module

```bash
# Build module package
pdk build

# The tarball will be in pkg/
```

### Generating Documentation

```bash
# Generate REFERENCE.md
puppet strings generate --format markdown

# Preview documentation
puppet strings server
# Open http://localhost:8808
```

## Module Architecture Guidelines

### Key Design Principles

1. **Dependency Management**: Hard dependency on `puppet_data_connector` - always use `require => Class['puppet_data_connector']`
2. **Configuration Discovery**: Use `lookup()` to discover settings from existing modules rather than duplicating parameters
3. **Optional Features**: Use boolean flags for optional functionality (e.g., `enable_scm_collection`)
4. **Template-based Generation**: Scripts generated from EPP templates with all configuration injected as parameters
5. **Systemd Timers**: Use systemd timers instead of cron for SCE compatibility
6. **Exported Resources**: Use PuppetDB exported resources for server-to-client data distribution

### Adding New Features

When adding new features:

1. Consider backward compatibility
2. Use optional parameters with sensible defaults
3. Add comprehensive parameter validation
4. Include unit tests for all parameter combinations
5. Update documentation and examples
6. Consider impact on existing deployments

### Template Development

When modifying EPP templates:

1. Pass all configuration as template parameters
2. Avoid hardcoded values in templates
3. Include error handling in generated scripts
4. Use environment variables for sensitive data when possible
5. Test generated scripts independently

## Release Process

Maintainers will handle releases following semantic versioning:

- **Major** (X.0.0): Breaking changes
- **Minor** (0.X.0): New features, backward compatible
- **Patch** (0.0.X): Bug fixes, backward compatible

## Questions or Need Help?

- Open an issue for questions
- Tag issues with appropriate labels
- Be patient and respectful

## Licence

By contributing, you agree that your contributions will be licenced under the Apache Licence 2.0.

Thank you for contributing!
