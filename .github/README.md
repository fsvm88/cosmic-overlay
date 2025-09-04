# GitHub Actions Workflows

This directory contains the CI/CD workflows for the COSMIC overlay repository.

## Workflows

### QA Check (`qa-check.yml`)

Comprehensive quality assurance checks for the overlay using modern Gentoo QA tools (`pkgcheck` and `pkgdev`).

**Triggers:**

- Push to `main`/`master` branch
- Pull requests to `main`/`master` branch
- Weekly schedule (Sundays at 06:00 UTC)
- Manual dispatch

**What it does:**

- Sets up a Gentoo environment in Docker
- Runs `pkgcheck scan` to analyze all packages
- Performs `pkgdev manifest` validation
- Generates HTML and Markdown reports with detailed analysis
- Comments on PRs with QA results
- Creates GitHub issues on failures
- Uploads reports as artifacts

**Outputs:**

- QA reports (HTML + Markdown)
- Raw pkgcheck logs (text and JSON)
- pkgdev validation results
- Category-specific check results

### Deploy Pages (`deploy-pages.yml`)

Deploys QA reports to GitHub Pages for public viewing.

**Triggers:**

- After successful completion of QA Check workflow on main branch

**What it does:**

- Downloads QA reports from the previous workflow
- Deploys them to GitHub Pages
- Makes reports publicly accessible

## Reports Location

- **GitHub Pages**: `https://<username>.github.io/<repo>/qa-reports/`
- **Artifacts**: Available in each workflow run for 30 days
- **PR Comments**: Inline summaries for pull requests

## Configuration

### Required Permissions

The workflows require these permissions:

- `contents: read` - To checkout repository
- `pages: write` - To deploy to GitHub Pages
- `id-token: write` - For GitHub Pages deployment
- `issues: write` - To create failure notifications

### Secrets

No additional secrets required - uses default `GITHUB_TOKEN`.

## Customization

### Modifying QA Checks

Edit `qa-check.yml` to:

- Add more pkgcheck scanning options
- Include additional validation tools
- Modify Docker environment setup
- Change notification behavior

### Report Generation

The `scripts/generate-qa-report.py` script can be customized to:

- Change report format and styling
- Add additional metrics from pkgcheck JSON
- Modify HTML templates
- Include more package statistics

### Scheduling

Modify the cron expression in `qa-check.yml`:

```yaml
schedule:
  - cron: "0 6 * * 0" # Weekly on Sunday at 06:00 UTC
```

## Tool Migration

### Modern QA Stack (Current)

- **pkgcheck**: Advanced QA scanning with multiple severity levels
- **pkgdev**: Modern development toolkit for manifests
- **Rich Output**: JSON and text reports with detailed categorization

### Legacy Support

- **repoman**: Maintained for backward compatibility
- **Auto-detection**: Workflows adapt to available tools
- **Gradual transition**: Moving towards pkgcheck-only workflows

## Troubleshooting

### Common Issues

1. **Docker build failures**: Check Gentoo base image availability
2. **pkgcheck errors**: Verify overlay structure and packages
3. **Pages deployment**: Ensure GitHub Pages is enabled in repository settings
4. **Permission errors**: Check workflow permissions in repository settings

### Debugging

- Check workflow logs in Actions tab
- Download artifacts for detailed reports
- Test scripts locally with Docker
- Verify pkgcheck works in local Gentoo environment

## Cost Considerations

**GitHub Actions Usage:**

- Estimated: 90-180 minutes/month
- Free tier: 2,000 minutes/month (public repos)
- Should remain within free limits

**Optimization Tips:**

- Cache Docker layers when possible
- Skip checks for documentation-only changes
- Use targeted pkgcheck scans for large PRs
- Adjust schedule frequency as needed
