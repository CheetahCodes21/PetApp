# Daily questions — how to edit the question set

The home screen shows one **daily question**. All the wording lives in a single
file:

> **`PetApp/Services/DailyPrompts.swift`** — the only place you edit questions.

Editing this file is **low-merge-risk**: it's a plain data list that no other
feature owns, so the wording can be updated freely and often without stepping on
other people's work. UI, recording, and the widget all read from it — they do not
need to change when you edit questions.

## The two layers

Questions come in two layers:

| Layer         | What it is                                              | When it's used                                  |
| ------------- | ------------------------------------------------------- | ----------------------------------------------- |
| `anchors`     | A light everyday **yes/no** opener + a `followUpYes`.   | The daily driver, shown first.                  |
| `reflections` | Deeper, nostalgic standalone prompts.                   | The gentle **"no"** fallback / a slower prompt. |

Flow: the anchor is asked first. **Yes** → the `followUpYes` becomes the question
the user answers. **No** → a `reflection` is offered instead (no second yes/no
layer). Either way it resolves to one string handed to the recorder unchanged.

## Editing

- **Add / change an anchor** — add or edit a `DailyPrompt` in the `anchors` array:
  ```swift
  DailyPrompt(id: "outside",
              anchor: "Did you go outside today?",         // the yes/no opener
              followUpYes: "Where did you go, and how was the weather?"),
  ```
- **Add / change a reflection** — add or edit a string in the `reflections` array.
- **`id`** must be unique and stable (kebab-case). Keep it stable even if you
  reword the text, so analytics / any future persistence stay consistent.

### Wording conventions

- **Anchors** are answerable yes/no and about *today / recent, ordinary life*
  (food, going out, people, sleep, something watched). Keep them easy to answer
  day after day.
- **`followUpYes`** must read as a standalone question (it becomes the recorded
  prompt on its own), e.g. *"What was it, and who made it?"*
- **Reflections** are warmer, open, and nostalgic.
- Keep the tone gentle and conversational — not a questionnaire.
- Strings are used as **localization keys** (`LocalizedStringKey`). When adding a
  new question, also add its translations in `Localizable.xcstrings`.

## What NOT to touch

The rest of the pipeline reads `DailyPrompts` and should not need edits when you
change questions:

- `Views/Home/HomeView.swift` — shows the question, drives the flow.
- `Services/WidgetSync.swift` — publishes `todayAnchor.anchor` to the widget.
- The recording flow (`Recording/…`) — receives the resolved question string.
