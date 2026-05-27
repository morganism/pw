# 🚀 Sinatra Docker Template

[![Tests](https://github.com/YOUR-USERNAME/YOUR-REPO/actions/workflows/test-dockerized-app.yml/badge.svg)](https://github.com/YOUR-USERNAME/YOUR-REPO/actions/workflows/test-dockerized-app.yml)
[![Docker Build](https://img.shields.io/docker/cloud/build/YOUR-DOCKER-USERNAME/YOUR-IMAGE-NAME)](https://hub.docker.com/r/YOUR-DOCKER-USERNAME/YOUR-IMAGE-NAME)

This is a *GitHub template* for quickly setting up a *Dockerized Sinatra application*. You can use this repository to bootstrap new applications with minimal effort.

---

## 🛠 Features

- *Sinatra* - A lightweight Ruby web framework.
- *Docker* - Containerized environment for easy deployment.
- *RSpec* - Automated testing with GitHub Actions.
- *Rack* - Manages web server requests via config.ru.

---

## 🚀 Getting Started

### 1️⃣ *Using the Template*
Click the *"Use this template"* button on GitHub to create a new repository.

### 2️⃣ *Clone the Repository*
```sh
git clone https://github.com/YOUR-USERNAME/YOUR-REPO.git
cd YOUR-REPO

3️⃣ Generate a New Sinatra App

ruby setup.rb

4️⃣ Run the Application

docker-compose up --build

Your app will be available at http://localhost:4567.

🛠 Running Tests

Run RSpec tests locally:

bundle exec rspec

🔄 Automated Testing in GitHub Actions

Every push and pull request triggers:
	•	Build and run the Docker container
	•	Execute RSpec tests
	•	Ensure /health endpoint works

✅ Badges update automatically based on test status.

🏗 Contributing

Feel free to submit pull requests to improve this template!

📜 License

This project is licensed under the MIT License.

---
