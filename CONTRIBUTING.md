# Contributing to Homelab DevOps Pipeline

Thank you for your interest in contributing! This project welcomes contributions from the community to help improve the automation code and make it more useful for everyone building homelabs.

## Ways to Contribute

- 🐛 Report bugs and issues
- 💡 Suggest new features or improvements
- 📝 Improve documentation
- 🔧 Submit code improvements
- ✅ Help test on different environments
- 📖 Share your experience using this in your own homelab

## Getting Started

1. **Fork the repository**
   ```bash
   # Click "Fork" on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/massoteau-homelab-devops.git
   cd massoteau-homelab-devops
   ```

2. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

3. **Make your changes**
   - Follow the code guidelines below
   - Test your changes thoroughly
   - Update documentation as needed

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: Add feature description"
   ```

   Use conventional commits:
   - `feat:` New feature
   - `fix:` Bug fix
   - `docs:` Documentation changes
   - `refactor:` Code refactoring
   - `test:` Testing improvements
   - `chore:` Maintenance tasks

5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request**
   - Go to your fork on GitHub
   - Click "New Pull Request"
   - Describe your changes
   - Reference any related issues

## Code Guidelines

### Ansible

- **Follow Ansible best practices**
  - Use fully qualified collection names (e.g., `ansible.builtin.copy`)
  - Always include `name` for tasks
  - Use YAML lint and ansible-lint before submitting

- **Role structure**
  ```
  roles/role-name/
  ├── README.md          # Role documentation
  ├── defaults/main.yml  # Default variables
  ├── tasks/main.yml     # Main tasks
  ├── handlers/main.yml  # Handlers
  └── templates/         # Jinja2 templates
  ```

- **Document variables**
  - All variables in `defaults/main.yml` need comments
  - Provide sensible defaults
  - Document variable types and examples

- **Idempotency**
  - Playbooks must be idempotent (safe to run multiple times)
  - Test with `--check` mode
  - Verify no changes on second run

- **Testing**
  ```bash
  # Syntax check
  ansible-playbook playbooks/your-playbook.yml --syntax-check

  # Lint check
  ansible-lint playbooks/your-playbook.yml

  # Check mode (dry run)
  ansible-playbook playbooks/your-playbook.yml --check
  ```

### Scripts

- **Use bash strict mode**
  ```bash
  #!/bin/bash
  set -e  # Exit on error
  set -u  # Exit on undefined variable
  set -o pipefail  # Exit on pipe failure
  ```

- **Add usage information**
  ```bash
  usage() {
    echo "Usage: $0 [options]"
    echo "  -h    Show this help message"
    echo ""
    echo "Example: $0 -h"
  }
  ```

- **Include comments for complex logic**
  - Explain "why" not "what"
  - Document assumptions and dependencies

- **Make scripts idempotent when possible**
  - Check if action is needed before executing
  - Don't fail if already in desired state

### Terraform (Coming Soon)

- Use Terraform 1.5+ features
- Pin provider versions
- Include examples in `examples/` directory
- Document all variables with descriptions

## Testing

Before submitting a pull request:

### Ansible Testing

```bash
# 1. Syntax check
cd ansible
ansible-playbook playbooks/*.yml --syntax-check

# 2. Lint check
ansible-lint playbooks/*.yml

# 3. Test on your environment (if possible)
ansible-playbook playbooks/01-network-setup.yml --check -i inventory/hosts.ini
```

### Script Testing

```bash
# Test on a VM or container first
# Verify it doesn't modify production systems
# Check exit codes and error handling
```

## Documentation

- **README files**
  - Each role should have a README.md
  - Include: purpose, variables, examples, dependencies

- **Comments**
  - Use clear, concise language
  - Keep comments up to date with code changes
  - Avoid obvious comments

- **Example files**
  - Provide `.example` templates for configuration files
  - Include comments explaining each option

## Pull Request Process

1. **Update documentation**
   - Update README if adding features
   - Update role documentation if changing roles
   - Add examples for new functionality

2. **Test thoroughly**
   - Run syntax checks
   - Run lint checks
   - Test on actual infrastructure if possible

3. **Keep PRs focused**
   - One feature/fix per PR
   - Don't mix refactoring with new features
   - Smaller PRs are easier to review

4. **Describe your changes**
   - What does this PR do?
   - Why is this change needed?
   - How was it tested?
   - Any breaking changes?

5. **Be responsive**
   - Address review comments promptly
   - Ask questions if feedback is unclear
   - Update PR based on feedback

## Reporting Bugs

When reporting bugs, include:

1. **Environment information**
   - OS version (e.g., Ubuntu 22.04)
   - Ansible version (if applicable)
   - Article/section reference

2. **Steps to reproduce**
   ```
   1. Run command '...'
   2. See error
   ```

3. **Expected behavior**
   - What you expected to happen

4. **Actual behavior**
   - What actually happened

5. **Logs/Output**
   ```
   [Paste relevant logs here]
   ```

6. **Possible solution** (optional)
   - If you have ideas on how to fix it

## Feature Requests

When requesting features:

1. **Describe the problem**
   - What are you trying to accomplish?
   - Why can't you do it now?

2. **Describe the solution**
   - What would you like to see?
   - How would it work?

3. **Alternatives considered**
   - What other solutions did you consider?
   - Why is this approach better?

4. **Additional context**
   - Screenshots, examples, or references

## Security

- **Never commit sensitive data**
  - No passwords, API keys, or tokens
  - No IP addresses of production systems
  - Use `.gitignore` to protect sensitive files

- **Report security issues privately**
  - Email: [your-email-here] (not public issues)
  - Include steps to reproduce
  - We'll work with you to fix it

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback
- No harassment or discrimination
- Keep discussions professional

## Questions?

- Open an issue for questions
- Check existing issues first
- Use GitHub Discussions for general questions
- Tag issues appropriately

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

## Quick Checklist

Before submitting a PR:

- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No secrets or credentials committed
- [ ] Tested changes thoroughly
- [ ] Ansible syntax check passed
- [ ] ansible-lint passed (if Ansible changes)
- [ ] Commit messages follow conventional format

---

**Thank you for contributing!**

Your help makes this project better for everyone building homelabs.
