---
layout: post
title: Using testing models to improve tests readability
subtitle: Refreshing the page object model
date: 2024-10-08 00:34:00 -0700
tags: [testing, acceptance]
mermaid: true
credit-img: Photo by <a href="https://unsplash.com/@danielkcheung?utm_content=creditCopyText&utm_medium=referral&utm_source=unsplash">Daniel K Cheung</a> on <a href="https://unsplash.com/photos/white-stormtroopers-minifig-ZqqlOZyGG7g?utm_content=creditCopyText&utm_medium=referral&utm_source=unsplash">Unsplash</a>
cover-img: assets/img/house_model_code.png
thumbnail-img: assets/img/house_model_code_tn.png
---

{: .box-warning }
Testing web applications effectively can be challenging, especially as they grow in complexity. As the application evolves, changes to the UI, components, or structure can require significant updates to the test suite. This often leads to a maintenance burden, where tests become brittle and harder to manage.

## Introduction

Testing tools (like [playwright](https://playwright.dev/) for end to end testing or [react testing library](https://testing-library.com/docs/react-testing-library/intro/) combined with [jest](https://jestjs.io/) for unit testing) provide APIs to make testing web applications less complex and accessible.

Here is an example of an end to end test using _Playwright_ to illustrate what the APIs looks like:

```js
const { test, expect } = require('@playwright/test');

test.describe('When the user logs in', () => {
  test('The dashboard is displayed', async ({ page }) => {
    await page.goto('https://example.com/landing');
    await page.fill('#username', 'testuser');
    await page.fill('#password', 'password123');
    await page.click('#login-button');
    await expect(page).toHaveURL('https://example.com/dashboard');
  });
})

```

Using the _react testing library_ is similar and we will talk about that a bit later.

### Looking great ... right?

At first glance, this test looks fine. It directly targets the `#username`, `#password`, and `#login-button` elements on the page. However, the test is tightly coupled to the current implementation of the login page, meaning it depends heavily on the exact IDs or classes of those elements. If the page changes—whether it’s a redesign, a change in naming conventions, or even a refactor that alters the HTML structure—this test will break.

#### Impact of changes in the HTML

Imagine your development team decides to refactor the login page, and they change the `#login-button` to `#submit-button` to follow a more standardized naming convention:


```html
<!-- Old version -->
<button id="login-button">Log In</button>

<!-- New version -->
<button id="submit-button">Log In</button>
```

Suddenly, your entire test suite could break because every test that interacts with #login-button now needs to be updated. This might require going through all the tests where this button is used and manually changing the selector. Even though the behavior of the page is the same (a user can still log in), all the tests that reference this specific selector will fail.

For applications with hundreds of pages, this maintenance cost becomes unmanageable and causes teams to spend excessive time on test upkeep rather than focusing on actual testing and delivering value.

#### Repetition

Multiple test may access the same portion of the page to assert different scenarios, for example a test that checks for a successful login and another test that checks for a login that fails:

```js
test.describe('When the user logs in', () => {

  test.describe('And the user is already registered', () => {
    test('The dashboard is displayed and a message notifies the user', async () => {
      // Given
      const { user, passwrod } = await createRegisteredUser();
      await page.goto('https://example.com/landing');

      // When
      await page.fill('#username', user);
      await page.fill('#password', password);
      await page.click('#login-button');

      // Then
      await expect(page).toHaveURL('https://example.com/dashboard');
    })
  })

  test.describe('And the user does not have an account', () => {
    test('A message is displayed notifying the user', async () => {
      // Given
      const { user, password } = await createNotRegisteredUser()
      await page.goto('https://example.com/landing');

      // When
      await page.fill('#username', user);
      await page.fill('#password', password);
      await page.click('#login-button');

      // Then
      await expect(page).toHaveURL('https://example.com/dashboard');
    })
  })

  test.describe('And the user (some other scenario)', () => {
    // this scenario will repeat again
  })
})
```

Code repetition is problematic because it leads to harder maintenance, as any changes must be made in multiple places, increasing the risk of inconsistencies. It also makes the code more difficult to read and understand, and can lead to more bugs over time.


#### Readability woes

Using third party libraries is quite common. For example using [react-toastify](https://github.com/fkhadra/react-toastify) to show a message to the user after a successful login. The test may look like:

```js
test.describe('When the user logs in', () => {
  test('The dashboard is displayed and a message notifies the user', () => {
    // Given
    // a user and a password stored in the database

    // When
    // here is all the setup
  })

})
```

#### Why is this a problem?

* Frequent Test Failures: UI elements are subject to change frequently. Frontend developers might update element IDs, switch the structure of forms, or introduce new elements to improve accessibility or responsiveness. Each of these changes can cause a test to fail, even though the core functionality of the page remains unchanged.

* High Maintenance Costs: Every time a developer changes an element's ID or modifies the layout, all tests that reference that specific element need to be updated. For large applications, this can result in modifying hundreds or even thousands of tests, making maintenance cumbersome.

* Brittle Tests: Coupling tests to specific implementation details makes them brittle. Small, non-functional changes to the user interface, like renaming a button or changing an input field’s ID, can cause an entire suite of tests to fail even though the core user behavior hasn’t changed. This leads to time spent on "false negatives"—tests that fail due to superficial changes rather than true bugs.

* Reduced Readability: Tests that reference specific elements directly often read like implementation details rather than focusing on user intent. For example, await page.click('#login-button') speaks about clicking a specific button, but doesn’t explain the broader context—such as logging in.

## Solution through abstraction

To address these issues, we need to introduce one or more abstractions (Page Object Models, POMs for short), which decouple the tests from the underlying page implementation. Instead of having tests directly reference specific elements, you encapsulate the page interactions in a separate data type.


This abstraction means that the tests no longer care about specific selectors or HTML structures—they care about the business logic and user interactions.

Let us build this data type using the same example as before:

```js
const { test, expect } = require('@playwright/test');

test('User can log in', async ({ page }) => {
  await page.goto('https://example.com/landing');
  await page.fill('#username', 'testuser');
  await page.fill('#password', 'password123');
  await page.click('#login-button');
  await expect(page).toHaveURL('https://example.com/dashboard');
});

```

## Conclusion

Abstracting your tests with Page Objects in Playwright is a best practice that simplifies test maintenance, improves readability, and makes your tests more resilient to changes in the UI. By isolating page-specific logic in separate classes, you minimize duplication and ensure that changes in the UI impact only the relevant Page Objects, rather than every test.

Playwright, with its flexibility and powerful APIs, pairs perfectly with the Page Object Model to create robust, scalable, and maintainable test suites. This approach not only makes your tests easier to read and manage but also future-proofs them against inevitable changes to the application.

Now, next time your web app changes, your tests won't break—just update the abstraction layer, and you're good to go!
