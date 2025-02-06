---
layout: post
title: "State management evolution (part II)&#58; Using MVVM"
subtitle: A tongue twister that will blow your mind
tags: [react view-model state]
mermaid: true
credit-img: Photo by https://unsplash.com/photos/brown-chillax-board-B6na4YFIecI
cover-img: assets/img/chillax.jpg
thumbnail-img: assets/img/chillax_tn.jpg
---


{: .box-intro }
The MVVM (Model-View-ViewModel) design pattern can simplify code maintenance and reduce the coupling between components and the implementation of state management.


## Introduction

In [Part I]({{page.previous.previous.url}}) of the series we explored using a reducer to manage state in a web application. To bring you up to speed, we began with an example that required managing multiple states to control the logic of a React component. After a few iterations, we evolved the example into one that uses the `useReducer` hook, which explicitly captures the events that modify the view's state.


The example focused on a student form that needed to be filled out with student information (first name and last name). The code used can be found [here](https://stackblitz.com/edit/vitejs-vite-ok7dwj?file=src%2FStudentForm.jsx).


```jsx

const initialState = {
  student: {
    studentId: 0,
    firstName: '',
    lastName: '',
  },
  errors: [],
  canSubmit: false,
  isLoading: false,
};

const studentReducer = (oldState, action) => {
  switch (action.type) {
    case 'student_changed':
      return changeStudentEvent(action.fieldName, action.value, oldState);
    case 'fetching_id_started':
      return fetchingIdStartedEvent(oldState);
    case 'fetching_id_finished':
      return fetchingIdFinishedEvent(action.newId, oldState);
  }
  throw Error('Action type invalid:' + action.type)
};

const StudentForm = (reducerFn = studentReducer) => {
  // State to store student data
  const [state, dispatch] = useReducer(reducerFn, initialState);

  ....
}

```

### What's the problem?

Working with the `useReducer` hook can be perfectly fine, but I believe there are a few areas for improvement.

Pros:
* The logic is separated from the view, reducing coupling.
* The state can be immutable.
* Separating the reducer function makes it easier to test, especially if you pass the reducer as an argument rather than hardcoding it to the view.

Cons:
* Using multiple hooks increases complexity.
* There is boilerplate code to create events and raise them with the proper arguments.
* There isn’t a clear separation between the model (used in the domain) and the view (used to satisfy UI needs).


## In a Nutshell

In the MVVM pattern, the _ViewModel_ serves as the intermediary between the _Model_ (business/data layer) and the _View_ (UI). It encapsulates all business logic, ensuring that the view remains free from complex calculations and state transitions. By centralizing logic in the ViewModel, developers can isolate and manage business rules in a cohesive and organized manner.


Another strength of _MVVM_ is its ability to expose only the necessary data and actions to the _View_. The _ViewModel_ acts as a tailored API for the _View_, presenting data in a format that’s easy to consume (e.g., formatted strings or precomputed values). This reduces boilerplate in the UI and ensures a clear contract between the View and ViewModel.

Consider the Tiny Counter example, where the Model is simply a counter:

```js
const Counter = {
  value: 0
}
```

The corresponding ViewModel represents everything the View needs. It provides a value for the counter and functions to increment and decrement the counter:

```js
const CounterViewModel = {
   value,
   increment,
   decrement
}
```
This ViewModel can then be passed as an argument to the component:


```jsx
import React, { useState } from 'react';

const Counter = (vm) => {
  const [count, increment] = vm(0);

  return (
    <div>
      <p>You clicked {count} times</p>
      <button onClick={increment}>
        Click me
      </button>
    </div>
  );
}
```

The ViewModel provides exactly what the component needs, establishing a one-to-one relationship that simplifies their interaction.

Inside the _ViewModel_, you are free to use a reducer hook or any other technology, with the implementation remaining hidden from the view. Testing becomes straightforward because the responsibilities of the View and ViewModel are clearly defined.


## Back to the Student Form

In the next section, we modify the student form to switch from a useReducer hook to a _ViewModel_. You can find all the code [here](https://stackblitz.com/edit/vitejs-vite-gtr44uvm).

To build a _ViewModel_ that provides only what the view needs you must create an object that has:

* Student information to display in the fields.
* A flat indicating whether the student ID is still loading.
* A flag indicating if there are errors to display (which means the form cannot be submitted).
* Handlers for changing the value of the fields.
* A handler for form submission.

For a view model _hook_, imagine a constructor that returns three values:

```jsx
const StudentForm = ({viewModel = StudentFormViewModel}) => {
  // State to store student data
  const [state, handleForm, handleField] = viewModel()

  if (state.isLoading) {
    return <h3>Fetching ID... please wait</h3>;
  }

  return ( .... )
}

```

Note that much of the logic has already been moved out of the view and into the ViewModel, which makes the view smaller:


```jsx
  // Not needed, part of the VM
  const handleChange = (e) => {...};

  // Not needed, part of the VM
  useEffect(() => { ... }, []);

  // Not needed, part of the VM
  const handleSubmit = (e) => { ... };
```

The state remains unchanged. Here is a refresher:

```js
const initialState = {
  student: {
    studentId: 0,
    firstName: '',
    lastName: '',
  },
  errors: [],
  canSubmit: false,
  isLoading: false,
};

```

The view logic does not change; it still uses handlers to notify changes and receive updates:

```jsx
const StudentForm = ({viewModel = StudentFormViewModel}) => {
  // State to store student data
  const [state, handleField, handleForm] = viewModel()

  if (state.isLoading) {
    return <h3>Fetching ID... please wait</h3>;
  }

  return (
    <form onSubmit={handleForm}>
      <div>
        <label>Student ID:</label>
        <input
          type="text"
          name='studentId'
          value={state.student?.studentId}
          onChange={handleField('studentId')}
          readOnly={true}
        />
      </div>
      <div>
        <label>First Name:</label>
        <input
          type="text"
          name="firstName"
          value={state.student?.firstName}
          onChange={handleField('firstName')}
        />
      </div>

      // rest of the form
      ...

    </form>
  );
};

```

The implementation of the _ViewModel_ is not the focus right now; feel free to look at the code.


### Binding the values

Another benefit of using a _ViewModel_ is the ability to bind parts of the _ViewModel_ to the view. The _ViewModel_ can use its tailored nature to simplify the view's declaration.

In the code above, it is evident that each field in the form requires a corresponding element in the _ViewModel_. This means that there is some repetition for each input field:


```jsx
    <form onSubmit={handleForm}>
      <div>
        <label>Student ID:</label>
        <input
          type="text"
          name='studentId'                    // repeat for every field
          value={state.student?.studentId}    // repeat ...
          onChange={handleField('studentId')} // repeat ...
          readOnly={true}
        />
      </div>
      <div>
        <label>First Name:</label>
        <input
          type="text"
          name="firstName"                    // same here... repeat...
          value={state.student?.firstName}
          onChange={handleField('firstName')}
        />
      </div>
      ...
  </form>
```

Using a function to bind the values can reduce this boilerplate. A simple implementation replaces the handlers in the _ViewModel_ with functions that return the attributes needed for each field:


```jsx

const StudentForm = ({viewModel = StudentFormViewModel}) => {
  const [state, bindInput, bindForm] = viewModel()
  ...
}

```

The function `bindInput` is used for individual fields, and `bindForm` is used for the entire form:

```js
  <form {... bindForm()}>
      <div>
        <label>Student ID:</label>
        <input type="text" {... bindInput('studentId')} readOnly={true}/>
      </div>
      <div>
        <label>First Name:</label>
        <input type="text" {... bindInput('firstName')}/>
      </div>
      ...
  </form>

```

The _binding_ functions connect the handlers inside the view model:

```jsx
  const bindInput = (name) => ({
    name,
    value: state.student[name],
    onChange: handleChange
  });

  const bindForm = () => ({ onSubmit: handleSubmit });

```

This binding approach reduces repetitive code and makes the view easier to follow:

```jsx
    <form {... bindForm()}>
      <div>
        <label>Student ID:</label>
        <input type="text" {... bindInput('studentId')} readOnly={true}/>
      </div>
      <div>
        <label>First Name:</label>
        <input type="text" {... bindInput('firstName')}/>
      </div>

      <div>
        <label>Last Name:</label>
        <input type="text" {... bindInput('lastName')}/>
      </div>

      ...
   </form>

```

## Looks cool, but how do I choose?

There are good practices you can adopt regardless of the pattern you choose.

### Passing an Argument to the View

Whether using a _ViewModel_ or a reducer function, passing it as a dependency to the component simplifies testing and helps separate concerns, decoupling business logic from the view.

### Using Immutable State

Using immutable state helps clarify which parts of the code are responsible for changes. This clarity simplifies maintenance, code reviews, and testing.

## Tipping the Scale

There is no harm in starting with a couple of state variables in the view and evolving later into a reducer, and eventually, a _ViewModel_.

If you find that you need more than one or two state variables to represent the view logic, or if the logic between states is becoming complex, it may be time to incorporate a reducer. If the number of reducer events grows and the code becomes harder to read, transitioning to a _ViewModel_ could be a great next step.

Consider these guideline questions:
* Is the complexity of the application growing?
* How easy is it to test the code?
* Can my peers read and understand the code on the first try?
* How many dependencies are required to implement the business logic?

If the answer to any of these questions takes more than a couple of seconds or if you find yourself saying "it depends," then it might be time to move to the next level.

Each move to a higher level of abstraction comes with a cost. While using a _ViewModel_ offers many benefits, it also requires substantially more code to design, write, and test.

Over time, experience will help you predict which approach to choose, foresee the benefits, and identify anti-patterns early.

