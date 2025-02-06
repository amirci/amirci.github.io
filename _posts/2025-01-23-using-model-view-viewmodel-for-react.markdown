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

The _ViewModel_ is _exactly_ what the component needs and the relationship is one to one making the relationship between them simpler.

Inside the _ViewModel_ we are free to use a _reducer_ hook or any other technology piece we see fit. However the implementation will stay hidden to the view.

The testing is straightforward because we understand at a glimpse the responsibilities of the _View_ and _ViewModel_ and how the should interact.

## Back to the student form

The next section tackles modifying the student form to switch from a `useReducer` hook to a view model. All the code can be found [here](https://stackblitz.com/edit/vitejs-vite-gtr44uvm).

To build a _ViewModel_ that provides only what the view needs we need to create an object that has:

* Student information to display in the fields
* A flat the identifies if the student ID is still loading
* A flag that identifies if there are errors to display (that means we cannot submit the form)
* Handle the change of the value of the fields
* Handle the form submission

In terms of a view model _hook_ I imagine a constructor that returns three values:

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

Please note that we have moved already a good portion of the logic out of the view to the _ViewModel_ making the view smaller:


```jsx
  // Not needed, part of the VM
  const handleChange = (e) => {...};

  // Not needed, part of the VM
  useEffect(() => { ... }, []);

  // Not needed, part of the VM
  const handleSubmit = (e) => { ... };
```

The `state` has not changed, here is a refresher:


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

The view logic has no changes, still uses the handlers to notify changes and get updates:

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

The implementation of the view model is not important for now, feel free to take a look at the code.


### Binding the values

Another aspect of using a _ViewModel_ is the opportunity to _bind_ the parts of the view model to the view.

That means that the view model takes _advantage_ of his tailored nature and uses this knowledge to simplify further the view declaration.

By looking at the code above is evident that each field in the form needs to have a counterpart in the view model, that means that there will be some repetition on each `input` field:

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

Using a function to bind the values will help to reduce boilerplate. A simple implementation could be to replace each handler in the view model with a function that will return the attributes needed for each field:

```jsx

const StudentForm = ({viewModel = StudentFormViewModel}) => {
  const [state, bindInput, bindForm] = viewModel()
  ...
}

```

The function `bindInput` will be used for fields and `bindForm` for the whole form:

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

The _binding_ functions can connect the handlers inside the view model:

```jsx
  const bindInput = (name) => ({
    name,
    value: state.student[name],
    onChange: handleChange
  });

  const bindForm = () => ({ onSubmit: handleSubmit });

```

The binding helps to remove repetitive code and makes the view easier to follow:

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

First there are a few good ideas that can be implemented no matter which pattern is used.

### Passing an argument to the view

Either with a view model or a reducer function, passing it as a dependency to the component simplifies testing and helps to separate concerns and decoupling the business logic from the view.

### Using immutable state

Having a state that cannot be modified will help to understand which parts of the code are actually generating changes. Clarity on where the changes occur simplify code maintenance, code reviews and testing.

### Tipping the scale

There is no harm in starting with a couple of states in the view and later evolve into a reducer and even later switch to a view model.

If you realize that you need more than one or two states to represent the logic behind the view or the requirements have changed and the logic between states is becoming more complex it may be time to incorporate a _reducer_.

When the events for the reducer are growing and the code is harder to read may be a great time to incorporate a _ViewModel_.

Some guideline questions could be:

* Is the complexity of the application growing?
* How easy to test is the code?
* Can my peers read the code and understand it on the first try?
* How many dependencies are needed to implement the business logic?

If the answer to any of these questions takes more than one or two seconds or you hear a "it depends", then, it is time to move to the next level.

Unfortunately, each move to the next level has a cost. Using a view model seems to be a very comprehensive solution with lots of benefits but requires substantially more code that has to be designed, written and tested.

In time, with experience, it will become easier to predict which one to choose to start, foresee the benefits and identify anti-patterns early.

