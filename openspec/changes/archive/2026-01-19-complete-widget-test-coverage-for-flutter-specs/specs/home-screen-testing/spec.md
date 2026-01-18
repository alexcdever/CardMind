## ADDED Requirements

### Requirement: Home Screen Spec Test Coverage
The system SHALL provide comprehensive widget tests for SP-FLUT-008 (Home Screen Specification), covering card list display, search functionality, and sync status indicators.

#### Scenario: Test card list display
- **WHEN** running the home screen spec test suite
- **THEN** all card list display scenarios SHALL be tested

#### Scenario: Test search functionality
- **WHEN** testing search interactions
- **THEN** all search scenarios from SP-FLUT-008 SHALL be covered

#### Scenario: Test sync status display
- **WHEN** testing sync status indicators
- **THEN** all sync status scenarios SHALL be verified

### Requirement: Test responsive layout behavior
The test SHALL verify home screen layout adapts correctly to different screen sizes.

#### Scenario: Test mobile layout
- **WHEN** screen width is below 1024px
- **THEN** mobile layout with bottom navigation SHALL be displayed

#### Scenario: Test desktop layout
- **WHEN** screen width is 1024px or above
- **THEN** desktop layout with side navigation SHALL be displayed

### Requirement: Test file location and naming
The test file SHALL be located at `test/specs/home_screen_spec_test.dart` and properly reference SP-FLUT-008.

#### Scenario: Correct file location
- **WHEN** creating the test file
- **THEN** it SHALL be placed in `test/specs/` directory

#### Scenario: Proper spec reference
- **WHEN** documenting the test file
- **THEN** it SHALL clearly reference SP-FLUT-008 in comments
