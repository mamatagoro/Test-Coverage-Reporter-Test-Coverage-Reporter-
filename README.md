# 🧪 Test Coverage Reporter

A Clarity smart contract for tracking and reporting test coverage metrics on the Stacks blockchain. Perfect for learning test design patterns and maintaining code quality! 

## 📋 Overview

The Test Coverage Reporter teaches essential test design concepts through a decentralized approach to tracking test suites, individual test cases, and coverage metrics. Built with Clarity for the Stacks ecosystem.

## ✨ Features

- 📊 **Test Suite Management** - Create and organize test suites with detailed metadata
- 🧪 **Test Case Tracking** - Add individual test cases with execution details
- 📈 **Coverage Reporting** - Track and update code coverage percentages
- 👥 **Permission System** - Grant/revoke access to test suite modifications
- 📊 **User Statistics** - Monitor individual user testing performance
- 🔒 **Secure Access Control** - Owner and permission-based modifications

## 🚀 Quick Start

### Creating a Test Suite

```clarity
(contract-call? .test-coverage-reporter create-test-suite 
    "Authentication Tests" 
    "Comprehensive test suite for user authentication flows")
```

### Adding Test Cases

```clarity
(contract-call? .test-coverage-reporter add-test-case 
    u1 
    "Login Validation" 
    "Tests user login with valid credentials")
```

### Updating Test Results

```clarity
(contract-call? .test-coverage-reporter update-test-result 
    u1 
    "passed" 
    u250 
    u15000)
```

### Setting Coverage Percentage

```clarity
(contract-call? .test-coverage-reporter update-coverage u1 u85)
```

## 📖 Core Functions

### 🔨 Write Functions

- `create-test-suite(name, description)` - Create a new test suite
- `add-test-case(suite-id, name, description)` - Add test case to suite
- `update-test-result(test-id, status, execution-time, gas-used)` - Update test execution results
- `update-coverage(suite-id, coverage-percentage)` - Set coverage percentage
- `grant-suite-permission(suite-id, user)` - Grant modification permissions
- `revoke-suite-permission(suite-id, user)` - Remove modification permissions
- `deactivate-test-suite(suite-id)` - Deactivate a test suite

### 👀 Read Functions

- `get-test-suite(suite-id)` - Retrieve test suite information
- `get-test-case(test-id)` - Retrieve test case details
- `get-user-permissions(suite-id, user)` - Check user permissions
- `get-user-stats(user)` - Get user testing statistics
- `can-modify-suite(suite-id, user)` - Check modification access

## 🏗️ Data Structures

### Test Suite
```clarity
{
    name: (string-ascii 100),
    description: (string-ascii 500),
    creator: principal,
    total-tests: uint,
    passed-tests: uint,
    failed-tests: uint,
    coverage-percentage: uint,
    created-at: uint,
    last-updated: uint,
    is-active: bool
}
```

### Test Case
```clarity
{
    suite-id: uint,
    name: (string-ascii 100),
    description: (string-ascii 300),
    status: (string-ascii 10),  ; "pending", "passed", "failed"
    execution-time: uint,
    gas-used: uint,
    created-at: uint,
    updated-at: uint
}
```

## 🛡️ Security Features

- **Owner Control**: Contract owner has ultimate authority
- **Permission System**: Granular access control per test suite
- **Creator Rights**: Test suite creators maintain full control
- **Validation**: Input validation for all parameters

## 🔧 Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js for testing utilities

### Setup
```bash
clarinet check
clarinet test
```

### Testing
```bash
clarinet test tests/test-coverage-reporter_test.ts
```

## 📊 Use Cases

- 🎓 **Educational**: Learn test design patterns and coverage concepts
- 🏢 **Enterprise**: Track team testing performance across projects
- 🔍 **Auditing**: Maintain immutable records of test execution
- 📈 **Analytics**: Generate testing insights and trends

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Write tests for new functionality
4. Submit pull request

## 📄 License

MIT License - see LICENSE file for details

## 🌟 Why Clarity?

This project demonstrates test design concepts using Clarity's:
- **Predictable execution** - No runtime surprises
- **Safe arithmetic** - Overflow protection built-in
- **Explicit error handling** - Clear success/failure paths
- **Immutable data** - Reliable state management

---

*Built with ❤️ for the Stacks ecosystem*
