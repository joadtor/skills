# Gherkin Reference

Distilled from the official Cucumber Gherkin reference
(https://cucumber.io/docs/gherkin/reference). Use it to write valid `.feature`
files. Indent with two spaces.

## File structure

- One `Feature` per `.feature` file; it comes first.
- A free-form description may follow any keyword line (Feature, Rule, Scenario,
  Examples) and runs until the next keyword — this is where narrative and
  rationale go.
- An optional `Background` comes before the scenarios.
- Optional `Rule` sections group scenarios; a `Rule` may hold its own
  `Background` and scenarios.
- A `Scenario Outline` requires one or more `Examples` sections.

## Keywords

### Feature
Groups related scenarios; a high-level description of a feature.
```gherkin
Feature: Guess the word
  As a player I want to guess a hidden word...   # free-form description lines
```

### Rule (Gherkin 6+)
Represents one business rule and groups its example scenarios. Optional.
```gherkin
  Rule: a guess is only allowed while the game is running
    Example: ...
```

### Scenario (a.k.a. Example)
A concrete example illustrating a business rule — a sequence of steps.
```gherkin
  Scenario: Breaker guesses a word
    Given the Maker has chosen a word
    When the Breaker makes a guess
    Then the Maker is asked to score
```

### Steps — Given / When / Then / And / But / *
- **Given** — initial context; put the system in a known state.
- **When** — the event or action (ideally one per scenario).
- **Then** — an observable expected outcome (an assertion).
- **And / But** — more steps of the previous kind; readability only.
- **\*** — replaces any step keyword; handy for list-like steps.
```gherkin
    Given one thing
    And another thing
    When the action happens
    Then the outcome holds
    But this other thing does not
```

### Background
`Given` steps run before each scenario in the feature (or rule). Use only for
genuinely shared setup.
```gherkin
  Background:
    Given a logged-in user
```

### Scenario Outline + Examples
Run the same scenario over many rows; `<placeholders>` come from the table.
```gherkin
  Scenario Outline: eating cucumbers
    Given there are <start> cucumbers
    When I eat <eat> cucumbers
    Then I should have <left> cucumbers

    Examples:
      | start | eat | left |
      |    12 |   5 |    7 |
      |    20 |   5 |   15 |
```

### Data Tables
A table passed as the last argument of a step.
```gherkin
    Given the following users exist:
      | name  | email          |
      | Alice | alice@test.dev |
```

### Doc Strings
Multiline text passed as the last argument of a step. Delimit with `"""` or
triple backticks.
```gherkin
    Given a blog post named "Random" with:
      """
      Some multi-line
      body text.
      """
```

### Tags
`@`-prefixed metadata on a Feature, Rule, Scenario, or Examples; groups and
filters independent of file structure.
```gherkin
  @smoke @checkout
  Scenario: ...
```

### Comments
A line starting with `#`. Ignored by Cucumber; available to reporters.

### Spoken language
A `# language:` header on the first line lets you write keywords in another
language.
```gherkin
# language: es
Característica: ...
```
