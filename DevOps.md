## 1. SonarQube

### 1.1 What & Why

- **Definition:** A continuous code quality platform that statically analyzes your codebase for bugs, vulnerabilities, code smells, duplicated code, coverage gaps, and more.
    
- **Business value:**
    
    - Early detection of issues → far cheaper to fix pre-release
        
    - Enforces team-wide quality standards and coding rules
        
    - Tracks quality over time with trend graphs and Quality Gates
        

### 1.2 Core Concepts

- **Projects & Keys:** Every repo or micro-app is a “Project” in SonarQube. A unique `projectKey` ties your code to its report.
    
- **Quality Profiles:** Collections of rules (e.g. “JavaScript: Sonar way”). You can customize: disable rules you don’t care about, tighten severity levels.
    
- **Quality Gates:** Boolean pass/fail checks (e.g. “No new blocker issues”, “Coverage ≥ 80%”). A failing gate can block merges.
    
- **Issues Types:**
    
    - **Bugs**: Certain malfunction or crash risk
        
    - **Vulnerabilities**: Security holes (XSS, SQLi, etc.)
        
    - **Code Smells**: Maintainability issues (long methods, magic numbers)
        
    - **Security Hotspots**: Require manual review
        

### 1.3 Setup & Configuration

1. **Deploy with Boeing Image**  
    Pull and run the official SonarQube image from Boeing’s registry:
    
    ```bash
    docker pull registry.web.boeing.com/container/images/util/sonarqube:9.4-949-1-2-2
    docker run --name sonarqube -p 9000:9000 registry.web.boeing.com/container/images/util/sonarqube:9.4-949-1-2-2
    ```
    
2. **First Login**  
    Browse to `http://<your-sonarqube-host>:9000`. Default admin/admin → change password immediately.
    
3. **Project & Token**  
    In the UI: **Create Project** → set a key (e.g. `react-app`) → generate and copy the analysis token.
    
4. **Scanner in CI**  
    Use Boeing’s Sonar scanner image in your pipeline:
    
    ```yaml
    sonar_scan:
      image: registry.web.boeing.com/container/images/util/sonarqube-node:imagetag
      stage: scan
      needs: [build]
      variables:
        SONAR_HOST_URL: "$SONAR_HOST"
        SONAR_LOGIN: "$SONAR_TOKEN"
      script:
        - sonar-scanner -Dsonar.host.url=$SONAR_HOST_URL -Dsonar.login=$SONAR_LOGIN
    ```
    
5. **Quality Gate**  
    Configure in UI: **Quality Gates** → copy or create one that enforces no new blockers and a coverage minimum (e.g. > 85%) → assign it to your project.
    

### 1.4 Advanced Tips

- **Branch Analysis:** enable feature-branch scanning in SonarQube for PR decoration.
    
- **Custom Rules:** add or disable rules to match your project coding standards.
    
- **Alerts:** hook SonarQube webhooks to notify your team on gate failures.
    
- **Branch analysis:** see feature branch vs. `main`.
    
- **Pull Request Decoration:** comments inline in GitLab MR.
    
- **Custom Rules:** write your own JavaScript or regex rules for project-specific patterns.
    
- **Webhooks & Alerts:** send Slack notifications when Gate fails.
    

---

## 2. Coverity Scan

### 2.1 What & Why

- **Definition:** A commercial-grade static analysis suite specialized in C/C++, Java, JavaScript, Python, etc., with deep path-sensitive checks.
    
- **Use case:** catch null derefs, buffer overflows, SQL injections, concurrency bugs that linters miss.
    
- **Free for OSS:** open-source projects get free scans on Coverity Scan service.
    

### 2.2 Workflow Overview

1. **Instrument build** with `cov-build`
    
2. **Analyze** with `cov-analyze`
    
3. **Upload** results to Coverity Scan cloud
    
4. **Review** defects in web portal; triage & assign
    

### 2.3 Installation & Setup

1. **Sign up & Project Setup**
    
    - Register at [https://scan.coverity.com](https://scan.coverity.com/) → create project → link GitLab/GitHub access.
        
2. **Install** on your build agent or dev machine; ensure `cov-build`, `cov-analyze`, `cov-format-errors` are in your `PATH`.
	
3. **Use Boeing Coverity Container**  
    In CI, reference Boeing’s Coverity image and bootstrap credentials:
    
    ```yaml
    coverity_scan:
      image: registry.web.boeing.com/container/images/util/coverity:9.4-1194-1-1
      stage: scan
      needs: [build]
      before_script:
        - chmod +x ./pipeline/ECSS_CURL_Client_Unix.sh
        - echo $ARTIFACTORY_USERNAME > /etc/yum/vars/sres_username
        - echo $ARTIFACTORY_API_TOKEN  > /etc/yum/vars/sres_api_token
        - microdnf install -y --nodocs java-11-openjdk-devel tar gzip
        - export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
        - export PATH=$JAVA_HOME/bin:$PATH
    ```

### 2.4 Running an Analysis

```bash
# 1) Clean previous data
docker exec -ti coverity_container rm -rf cov-int
# 2) Instrument and build
docker exec -ti coverity_container cov-build --dir cov-int mvn package
# 3) Analyze
docker exec -ti coverity_container cov-analyze --dir cov-int --all
# 4) Upload results
docker exec -ti coverity_container tar czf cov-out.tgz cov-int
curl -F project=my-react-app \
     -F token=$COVERITY_TOKEN \
     -F email=$COVERITY_EMAIL \
     -F file=@cov-out.tgz \
     https://coverity.boeing.com/api/upload

```

### 2.5 Inspecting Results

- **Dashboard:** sorted by severity (Critical/High/Medium/Low).
    
- **Triage:**
    
    - Mark false positives
        
    - Assign each defect to a dev
        
    - Add comments & link to Jira/GitLab issue
        

### 2.6 CI Integration

- **GitLab CI job:**
    
    ```yaml
coverity_scan:
  stage: scan
  needs: [build]
  image: registry.web.boeing.com/boeing-images/coverity:9.4-1194-1-1
  before_script:
    - chmod +x ./pipeline/ECSS_CURL_Client_Unix.sh
    - echo $ARTIFACTORY_USERNAME > /etc/yum/vars/sres_username
    - echo $ARTIFACTORY_API_TOKEN  > /etc/yum/vars/sres_api_token
    - microdnf install -y --nodocs java-11-openjdk-devel tar gzip
    - export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
    - export PATH=$JAVA_HOME/bin:$PATH
  script:
    - echo "Running Coverity scan via Boeing container"
  allow_failure: true
    ```

---

## 3. DevOps Best Practices for Developers

### 3.1 Version Control & Branching

- **Branch Strategy:**
    
    - `main` (production-ready), `develop` (integration), `feature/*`, `hotfix/*`.
        
    - Merge back via MRs with approvals.
        
- **Commits & PRs:**
    
    - One logical change per PR.
        
    - Clear commit messages: `<scope>(<area>): <short description>`
        
    - Link issues in commit messages: `Fixes #123`.
        

### 3.2 CI/CD Principles

- **Build once, deploy many:** create immutable artifacts (Docker images, ZIPs).
    
- **Fail fast:** broken build = immediate blocker.
    
- **Automate everything:** lint, tests, scans, deployments.
    

### 3.3 Infrastructure as Code (IaC)

- Store all infrastructure configs (Terraform, ARM templates, Helm charts) in Git.
    
- Peer-review changes.
    
- Use automated plan/apply pipelines with guardrails (e.g. manual approvals for prod).
    

### 3.4 Security “Shift Left”

- **Dependency scanning:**
    
    - `npm audit` or tools like Snyk/Bandit.
        
    - Automate weekly or on each PR.
        
- **Static Analysis:** SonarQube & Coverity (see above).
    
- **Secrets management:** vault services; never hardcode.
    

### 3.5 Observability & Monitoring

- **Logging:** structured logs (JSON), central aggregator (ELK, Splunk).
    
- **Metrics:** track custom app metrics (response times, error rates).
    
- **Tracing:** distributed tracing (OpenTelemetry) for HTTP calls.
    

### 3.6 Culture & Collaboration

- **Code reviews:** mandatory, constructive feedback.
    
- **Blameless postmortems:** when things break in prod.
    
- **Knowledge sharing:** brown-bag sessions, docs.
    

---

## 4. Testing in Dev & Prod

### 4.1 Dev Environment

1. **Unit Tests:** Jest + React Testing Library
    
    ```bash
    npm run test -- --coverage --watchAll=false
    ```
    
2. **Integration Tests:** API mocks, component + backend interaction.
    
3. **Smoke Testing:** deploy to dev server (`dev.example.com`), exercise key flows manually.
    
4. **Local E2E (optional):** Cypress in headed mode for quick debugging.
    

### 4.2 Staging/Prod Environment

1. **End-to-End Tests:**
    
    ```bash
    npx cypress run --config baseUrl=https://staging.example.com
    ```
    
2. **Load & Performance:** tools like k6 or Locust to simulate traffic spikes.
    
3. **Chaos Engineering (advanced):** introduce failures (latency, errors) to test resilience.
    
4. **Monitoring & Alerts:**
    
    - Sentry for frontend exceptions
        
    - Datadog/RUM for real user monitoring
        
    - PagerDuty alerts on error rate spikes
        

### 4.3 Test Data Management

- **Fixtures & Mocks:** control responses in dev.
    
- **Sandbox environments:** use isolated test DBs with anonymized data.
    

---

## 5. Access Control

### 5.1 Principle of Least Privilege

- Grant only needed permissions, revoke by default.
    

### 5.2 Environment Roles

|Role|Dev Access|Prod Access|
|---|---|---|
|**Developer**|Full: deploy, config, logs|Read-only: logs, dashboards|
|**QA / Tester**|Full: test data, debug, logs|None / limited: can view dashboards|
|**DevOps Engineer**|Full|Full: deploy, rollback, config|
|**Release Manager**|None|Can trigger manual prod deployments|

### 5.3 Implementation

- **GitLab Roles:** Developer, Maintainer, Reporter.
    
- **Cloud IAM:** AWS IAM roles with scoped policies (e.g. only S3 read/write to `dev-*` buckets).
    
- **Audit:** review access quarterly; log all deployment actions.
    

---

## 6. Development Best Practices

For a MERN application, keep your code reliable, readable, and maintainable. Focus on these core practices:

1. **Consistent Code Formatting**
    
    - Use Prettier via a shared config.
        
        
2. **Simplified Project Structure**
    
    - **Backend (Express/Node):**
        
        ```
        /server
          /controllers
          /models        ← Mongoose schemas
          /routes
          index.js
        ```
        
    - **Frontend (React):**
        
        ```
        /client
          /components
          /pages
          /services      ← API calls (use fetch or axios)
          App.js
          index.js
        ```
        
    - Keep shared types in a `/types` folder at root if using TypeScript.
        
3. **Module Boundaries**
    
    - One folder = one feature.
        
    - Export only what’s needed (e.g., `module.exports = { createUser }`).
        
4. **Error Handling & Logging**
    
    - Use a global error middleware in Express to catch and format errors.
        
    - On the React side, wrap components in an Error Boundary:
        
        ```jsx
        class ErrorBoundary extends React.Component { /* ... */ }
        ```
        
    - Log server errors with a centralized logger (e.g. Winston) and client errors to Sentry.
        
5. **Environment Variables Management**
    
    - Store DB URIs, API keys, secrets in `.env` (ignored in Git).
        
    - Load via `dotenv` in Node and via CI/CD variables in React builds.
        
6. **Security Basics**
    
    - **Backend:** sanitize inputs using `express-validator`.
        
    - **Frontend:** avoid `dangerouslySetInnerHTML`, validate user input.
        
    - Enable CORS only for allowed domains.
        
7. **API Interaction**
    
    - **Use Axios/fetch** with a shared service layer.
        
    - Centralize base URLs and headers configuration.
        
    - Handle HTTP errors and display user-friendly messages.
        
8. **Testing Essentials**
    
    - **Backend:** write simple Jest tests for controllers and models.
        
    - **Frontend:** use React Testing Library for critical UI components.
        
    - Run tests in CI with coverage thresholds (e.g., ≥ 70%).
        
9. **Performance Tips**
    
    - **Backend:** use indexing in MongoDB, avoid unbounded queries.
        
    - **Frontend:** lazy-load routes with `React.lazy`, memoize pure components.
        
10. **Deployment Readiness**
    
	- Build artifacts separately: `npm run build` in client, package server.
	    
	- Use Docker multi-stage builds: one for client build, one for Node server.
    
	- Health-check endpoints (`/health`) for readiness probes.
    

## 7. GitLab Pipeline Creation Process

### 7.1 Structure & Stages

```yaml
stages:
  - lint
  - test
  - build
  - scan
  - deploy_dev
  - deploy_prod
```

### 7.2 Job Examples

#### Lint

```yaml
lint:
  stage: lint
  image: node:18
  script:
    - npm ci
    - npm run lint
  artifacts:
    reports:
      codequality: gl-code-quality-report.json
```

#### Test

```yaml
test:
  stage: test
  image: node:18
  script:
    - npm ci
    - npm run test -- --coverage --watchAll=false
  coverage: '/All files\s*\|\s*\d+%/'
```

#### Build

```yaml
build:
  stage: build
  image: registry.web.boeing.com/.../ubi8-node20-python3
  cache:
    paths: [node_modules/]
  script:
    - npm ci
    - npm run build
  artifacts:
    paths:
      - dist/
      - webroot_project_dir.txt
    expire_in: 1 day
```

#### Deploy Dev

```yaml
deploy_dev:
  stage: deploy_dev
  image: alpine:latest
  script:
    - apk add --no-cache openssh-client
    - ssh deploy@dev-server "cd /var/www/react-app && git pull && npm ci && npm run restart"
  only:
    - develop
```

#### Manual Prod

```yaml
deploy_prod:
  stage: deploy_prod
  when: manual
  image: alpine:latest
  script:
    - apk add --no-cache openssh-client
    - ssh deploy@prod-server "cd /var/www/react-app && git pull && npm ci && npm run restart"
  only:
    - main
```

### 7.3 Tips & Tricks

- **Use CI variables:** store tokens, secrets in GitLab CI > Settings > Variables (masked/protected).
    
- **Artifact caching:** speed up `npm ci` by caching `~/.npm`.
    
- **Fail fast:** mark quality and test failures as blockers; optionally allow Coverity to fail without blocking if you’re iterating.
    

---

## Repository Review

### 1. `src/` Folder Structure

```text
api/                   ← API client wrappers or endpoints
apps/changeLog/        ← consider renaming to lowercase `changelog/` for consistency
assets/                ← images, fonts, static files
components/            ← reusable UI components
config/                ← application-level config (e.g. base URLs)
contexts/              ← React Context providers/hooks
pages/                 ← page-level components/routes
styles/                ← CSS/SCSS modules or global styles
types/                 ← TypeScript interfaces/types
utils/                 ← pure helper functions
App.tsx, main.tsx      ← entry points
vite-env.d.ts          ← Vite type definitions
```

**Observations & Suggestions:**

- **Naming consistency:**
    
    - Use lowercase or kebab-case for folders (`apps/changelog` vs. `apps/changeLog`).
        
    - Keep folder names singular where it makes sense (`context` vs. `contexts` only if multiple distinct contexts exist).
        
- **Depth vs. granularity:** If `apps/changeLog` holds just one or two files, collapse into a top-level folder or merge into `utils/` if it’s purely utility code.
    
- **Co-location:** Consider moving module-specific styles or types next to their component, e.g., `components/MyButton/MyButton.tsx` + `MyButton.module.css` + `index.test.tsx`.
    
- **Index files:** Add `index.ts` in folders to re-export modules, simplifying imports (e.g. `import { fetchUser } from 'api'`).
    

---

### 2. Repo-Wide Config & Ignored Files

- **`.env`**
    
    - Move secrets out of VCS into CI/CD variables.
        
    - Add `.env` to `.gitignore`; keep a `.env.example` with placeholder keys.
        
- **`.prettierrc`**
    
    - Add `.prettierrc` to `.gitignore` so formatting config is centralized (e.g., via an organization-level file).
        
    - Document the location or reference of the shared Prettier config in `README.md`.
        
- **TypeScript configs**
    
    - Ensure `tsconfig.json`, `tsconfig.app.json`, `tsconfig.node.json` each only include relevant `include`/`exclude` patterns to avoid overlap.
        

---

### 3. CI/CD & `.gitlab-ci.yml`

- **Branch rules & variables**
    
    - Consolidate branch checks into a `rules:` matrix instead of multiple `if` blocks.
        
    - Externalize hostnames and credentials completely into CI variables; avoid any defaults in the file.
        
- **Stage coverage**
    
    - Ensure `lint` and `test` stages run before `build`.
        
    - Add a `scan` stage if using SonarQube/Coverity (even if configured elsewhere).
        
- **Artifacts & caching**
    
    - Cache `node_modules/` and any long-lived build caches (e.g. Vite cache) with clear cache keys.
        
    - Set all `artifacts: expire_in:` values to prevent storage bloat.
        

---

### 4. Section Changes & Prioritization

- **Blockers (P1):**
    
    1. Remove sensitive files (`.env`, optionally `.prettierrc`) from VCS.
        
    2. Add/verify a `.gitignore` entry for these.
        
    3. Introduce mandatory `lint` & `test` jobs in CI.
        
- **Important (P2):**
    
    1. Refine folder naming and co-location strategy in `src/`.
        
    2. Parameterize all environment-specific values in CI.
        
    3. Standardize branch naming and casing.
        
- **Nice-to-Have (P3):**
    
    1. Co-locate tests and styles with components.
        
    2. Implement `index.ts` barrel files for cleaner imports.
        
    3. Document folder conventions and CI variable usage in `README.md` or a dedicated `CONTRIBUTING.md`.
        

---

**Final Opinion:**  
Your repo already covers the essentials (TypeScript, Prettier, ESLint, Vite, Dockerfile). By tightening up folder conventions, externalizing all sensitive configs, and enforcing CI jobs early, you’ll dramatically improve maintainability and security—while keeping the developer experience smooth and predictable.