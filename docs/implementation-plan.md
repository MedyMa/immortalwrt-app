# Implementation plan

1. Scaffold Flutter application and implement the overview/connection screens using a shared design system. Verify widget rendering and offline states.
2. Implement ubus session login, per-method readers, robust decoding, credential storage, and focused protocol tests.
3. Implement device, BE14 Wi-Fi, and traffic screens with explicit scope/recency labels. Test partial payloads and stale data.
4. Add Android/iOS network configuration and GitHub Actions analysis, tests, and build artifacts.
5. Verify locally where tooling permits, push the repository, then inspect the remote CI and repair any failures before calling the build complete.
