# pkgdown Configuration Guide

This project uses **pkgdown** to generate a professional documentation website for the picard package.

## Overview

**pkgdown** automatically generates a website from your package documentation by:
- Converting Roxygen documentation to HTML reference pages
- Organizing functions by topic
- Creating a navigation structure
- Hosting on GitHub Pages (via GitHub Actions)

## Files Created

- **`_pkgdown.yml`** - Configuration file for site structure, navigation, and reference organization
- **`.github/workflows/pkgdown.yml`** - Automated deployment via GitHub Actions to GitHub Pages
- **`docs/`** - Generated website folder (built locally or by CI/CD)

## Local Usage

### Build Site Locally

```r
# Install pkgdown if not already installed
install.packages("pkgdown")

# Build the site locally in docs/ folder
pkgdown::build_site()
```

### Preview the Site

After building, open the site in your browser:

```r
# Automatically opens the site in your browser
pkgdown::preview_site()
```

### Build Specific Components

```r
# Rebuild only the reference page
pkgdown::build_reference()

# Rebuild only the home page
pkgdown::build_home()

# Rebuild only the news/changelog
pkgdown::build_news()
```

## Automatic Deployment (GitHub Actions)

The workflow file `.github/workflows/pkgdown.yml` automatically:

1. **Triggers** when you push to the `main` branch (on changes to R/, man/, _pkgdown.yml, DESCRIPTION, etc.)
2. **Builds** the site using pkgdown
3. **Deploys** to GitHub Pages (gh-pages branch)

### Enable GitHub Pages

1. Go to your repository Settings → Pages
2. Select **Deploy from a branch**
3. Choose branch: **gh-pages**
4. Save

Your site will be available at: `https://ohdsi.github.io/picard/`

## Configuration Best Practices Used

### 1. **_pkgdown.yml Organization**
- Bootstrap 5 for modern responsive design
- Clear navbar structure (home, reference, articles, news, GitHub link)
- Functions organized by topic in the reference section
- Development mode set to auto for version badges

### 2. **Build Exclusions**
- Added `docs/` and `_pkgdown.yml` to `.Rbuildignore`
- Added related files to `.gitignore`
- Prevents documentation files from being included in the R package distribution

### 3. **GitHub Actions Workflow**
- Uses r-lib/actions for R setup (public RSPM for faster dependencies)
- Installs pkgdown and local package dependencies
- Deploys only on main branch pushes (not on PRs)
- Uses peaceiris/actions-gh-pages for secure deployment

### 4. **Autodiscovery**
- Reference functions organized with `starts_with()` patterns
- Reduces manual maintenance when you add new functions

## Customization

### Change the Site URL

Edit `_pkgdown.yml`:
```yaml
url: https://your-domain.com/picard/
```

### Add Articles/Vignettes

1. Create markdown files in `vignettes/` or `pkgdown/articles/`
2. They automatically appear in the Articles section
3. Update `_pkgdown.yml` to control their order and grouping

### Modify Navigation

Edit the `navbar` section in `_pkgdown.yml`:
```yaml
navbar:
  components:
    custom_link:
      text: My Link
      href: https://example.com
```

### Change Color Scheme

Add `bootswatch` theme to `_pkgdown.yml`:
```yaml
template:
  bootstrap: 5
  bootswatch: darkly  # or other Bootstrap theme
```

## Troubleshooting

### GitHub Actions Fails

1. Check **Actions** tab in your repository for logs
2. Common issues:
   - Missing GITHUB_TOKEN permissions (usually fixed automatically)
   - Roxygen documentation not built (`devtools::document()`)
   - Missing dependencies in DESCRIPTION

### Site Not Deploying

1. Verify GitHub Pages is enabled (Settings → Pages → gh-pages branch)
2. Check that workflow runs successfully
3. Site may take a few minutes to appear after first deployment

### Building Locally Without Network

```r
options(repos = c(CRAN = "https://cloud.r-project.org"))
pkgdown::build_site(devel = FALSE)
```

## Useful Commands Summary

```r
# Document your R code
devtools::document()

# Build the entire site
pkgdown::build_site()

# Preview in the browser
pkgdown::preview_site()

# Check the configuration
pkgdown::config_pluck()

# Clean and rebuild everything
pkgdown::clean_site()
pkgdown::build_site()
```

## Next Steps

1. **Rebuild documentation**: `devtools::document()`
2. **Build site locally**: `pkgdown::build_site()`  
3. **Enable GitHub Pages**: Settings → Pages (select gh-pages branch)
4. **Push to main**: The workflow will automatically deploy your site
5. **View your site**: `https://ohdsi.github.io/picard/`
