# Toolbar and TestFlight implementation plan

Goal: remove redundant toolbar refresh, retain pull refresh, use a standard platform settings action, and prepare a signed TestFlight delivery workflow.

- Use a 24 dp outlined gear in an Android Material IconButton, with system colors and no custom container; use a UIKit glass gear button on iOS, bridged into Flutter with a Cupertino fallback for host tests.
- Make short connected pages scrollable for pull refresh. Verify settings still opens the connection sheet.
- Provide manual signing/build/upload workflow, exact app profile validation and secret cleanup. Do not dispatch an upload without valid configured credentials and app record.
- Run Flutter format/analyze/tests and signing configuration tests. Push and verify routine CI starts.
