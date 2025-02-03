---
layout: post
title: "State management evolution (part II)&#58; Using MVVM"
subtitle: A tongue twister that will blow your mind
tags: [react]
mermaid: true
credit-img: Photo by xxx
cover-img: assets/img/house_model_code.png
thumbnail-img: assets/img/house_model_code_tn.png
---


{: .box-intro }
The MVVM (Model-View-ViewModel) design pattern can make the code easier to maintain and reduce the coupling between the component and the implementation of state management.

## Introduction

In [Part I]() of the series we explored using a _reducer_ to manage state in a web application. Today we are going to use the MVVM pattern to implement the example we used in the previous part, review the benefits and extract some guidelines.


#### **Example: A Student Questionnaire Form**

Imagine a student questionnaire form where some questions are static and straightforward, while others dynamically depend on previous answers. For instance, if a student selects "Yes" for "Do you have prior programming experience?", a follow-up question appears asking for the programming languages they know. Managing this conditional logic effectively can be achieved using either MVVM or `useReducer`.


#### **1. Capturing Business Logic in the View-Model vs. Reducer**

**MVVM**
In the MVVM pattern, the ViewModel serves as the intermediary between the Model (business/data layer) and the View (UI). It encapsulates all business logic, ensuring that the view remains free from complex calculations and state transitions. By centralizing logic in the ViewModel, developers can isolate and manage business rules in a cohesive and organized manner.

For example, in the student questionnaire, the ViewModel might manage the logic that determines which questions to show based on the student's previous answers. It ensures that the View only binds to properties like `isProgrammingQuestionVisible` or `programmingLanguages`, avoiding the need for the View to handle these conditions.

**useReducer**
The `useReducer` hook in React allows developers to manage complex state transitions using a reducer function, which defines how state updates are performed based on dispatched actions. While the reducer encapsulates some level of business logic, it’s often tightly coupled with state mutation. Business rules can still be abstracted into utility functions, but integrating these utilities requires additional effort.

For example, a reducer managing the questionnaire might handle actions like `ANSWER_QUESTION` or `TOGGLE_FOLLOW_UP`, updating the state to reflect which questions should be visible based on previous answers. While this approach works, the logic for determining visibility might be split between the reducer and components.

**Comparison**
- MVVM: Centralized, modular business logic in the ViewModel.
- useReducer: Encapsulates state transitions but may require additional layers for complete business rule abstraction.


#### **2. Providing Only What the View Needs**

**MVVM**
One of the MVVM’s strengths is its ability to expose only the necessary data and actions to the View. The ViewModel acts as a tailored API for the View, presenting data in a format that’s easy to consume (e.g., formatted strings or precomputed values). This reduces boilerplate in the UI and ensures a clear contract between the View and ViewModel.

For instance, in the questionnaire, the ViewModel might provide a `questionsToDisplay` array that includes only the relevant questions based on the student’s answers, with each question preformatted and ready for rendering.

**useReducer**
With `useReducer`, the state is shared directly with the component, often requiring the View to handle additional formatting or intermediate logic. While the reducer defines how state changes occur, the responsibility of transforming state into view-specific data often falls on the component.

For example, the reducer might store raw answers and visibility flags for questions, leaving the component to calculate which questions to display and how to format them.

**Comparison**
- MVVM: Provides preprocessed, view-specific data, minimizing the burden on the View.
- useReducer: Shares raw state, with the View handling transformation as needed.


#### **3. Testability: View-Model vs. Reducer**

**MVVM**
Because the ViewModel is independent of the UI, it’s inherently easy to test. Developers can write unit tests to validate business logic, state management, and commands without rendering the UI. The ViewModel’s clear separation of concerns ensures that tests remain focused and predictable.

For example, a unit test for the questionnaire ViewModel might verify that selecting "Yes" for a question correctly updates the `questionsToDisplay` array, without requiring any UI interaction.

**useReducer**
Reducers are also highly testable due to their pure function nature. Given the same inputs, they produce consistent outputs, making them ideal candidates for unit tests. However, since `useReducer` is often paired with components for state management, testing may involve additional setup to account for UI interactions or derived state.

For instance, testing a reducer’s `ANSWER_QUESTION` action is straightforward, but validating the entire flow of dynamically showing follow-up questions might require integration tests involving components.

**Comparison**
- MVVM: Isolated ViewModel logic simplifies unit testing, as no UI dependencies exist.
- useReducer: Reducers are testable in isolation, but derived state or UI logic may complicate testing.


#### **Conclusion**
Both MVVM and `useReducer` are effective patterns for managing state and business logic, but they cater to different needs:

- **MVVM** excels in larger applications where a clear separation of concerns, testability, and preprocessed view-specific data are priorities. The ViewModel’s ability to centralize business logic and present a clean API to the View ensures scalability and maintainability.
- **useReducer** shines in React-based projects that require lightweight, functional state management. Its simplicity and compatibility with React’s declarative paradigm make it a natural choice for medium-complexity applications.

When choosing between these approaches, consider the scale of your application, the complexity of your business logic, and your testing requirements. For robust, scalable solutions, MVVM is often the better choice. For simpler, React-native implementations, `useReducer` might be all you need.

