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

### Looking great! Right?

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

Multiple test may access the same portion of the page to assert different scenarios. For example a scenario could check for a successful login and another scenario validate an invalid login:

```js
test.describe('When the user logs in', () => {
  test.describe('And the user is already registered', () => {
    test('The dashboard is displayed and a message notifies the user', async ({ page }) => {
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
    test('A message is displayed notifying the user', async ({ page }) => {
      // Given
      const { user, password } = await createNotRegisteredUser()
      await page.goto('https://example.com/landing');

      // When
      await page.fill('#username', user);
      await page.fill('#password', password);
      await page.click('#login-button');

      // Then
      await expect(page.getByTestId('not-registered-message')).toBeInTheDocument();
    })
  })

  test.describe('And the user (some other scenario)', () => {
    // this scenario will repeat again most of the code
    // from the previous tests
  })
})
```

Code repetition is problematic because it leads to harder maintenance, as any changes must be made in multiple places, increasing the risk of inconsistencies. It also can lead to more bugs over time.


#### Readability woes

Using third party libraries is quite common. For example the [react-toastify](https://github.com/fkhadra/react-toastify) package can be used to show a message to the user after a successful login.

Let us assume the generated HTML for the toast would look like this:

```html
<div role="alert" class="Toastify__toast-body">
  <div class="Toastify__toast-icon Toastify--animate-icon Toastify__zoom-enter">
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="var(--toastify-icon-color-warning)">
      <path d="M...."></path>
    </svg>
   </div>
   <div>The marketplace token is missing.</div>
</div>
```

Then we could write a test that uses a _locator_ for the element with _class_ `Toastify__toast-body` that also contains the expected message in the inner HTML:

```js
test.describe('When the user logs in', () => {
  test('The dashboard is displayed and a message notifies the user', ({ page }) => {
    // Given
    const { user, passwrod } = await createRegisteredUser();
    await page.goto('https://example.com/landing');

    // When
    await page.fill('#username', user);
    await page.fill('#password', password);
    await page.click('#login-button');

    // Then
    // The message includes the email
    const message = `Welcome ${email}, good to see you!`;
    // Find the element with the toastify class that also contains the expected message
    const located = page.locator('.Toastify__toast').filter({ hasText: message })
    expect(located).toBeInTheDocument();
  })

})
```
Well-structured tests not only ensure functionality but also serve as documentation that guides future development and collaboration.

Writing tests that are easy to read, that use terms that are part of the domain under test (for example: login with a registered user, navigate to landing, display a welcome message) is crucial because they clearly express the intended behavior of the code leaving implementation details aside, making it easier for developers to understand the scenario being tested and making it straightforward to discuss with stakeholders.

## Solution through abstraction

To address these issues, we need to introduce one or more abstractions (Page Object Models, POMs for short), which decouple the tests from the underlying page implementation. Instead of having tests directly reference specific elements, the object will encapsulate the page interactions using terms that belong to the _domain_.

### Let the test drive

One way to approach discovering how to create the POMs for the page is to start writing the tests as if we would like to tell a story
that stakeholders could understand:

```gherkin
Given I am on the landing page
When I login with a registered user
Then I see my user's dashboard
And the application displays a welcome message
```

Looking good! Let us try to put in _playwright_ terms:

```js
test.describe('When the user logs in', () => {
  test('The dashboard is displayed and a message notifies the user', ({ page }) => {
    // Given
    const user = await createRegisteredUser();
    await Landing.open(page);

    // When
    await Landing.loginWith(user, page);

    // Then
    Dashboard.verify(page);
    expect(Dashboard.welcomeMessage(user.email, page)).toBeInTheDocument();
  })
})
```

Now we are talking! Let us see if we addressed the problems we identified in the [first section]():


The next step is to write the implementation. This is straightforward now the we have how we want to use it:

```js
const Landing = {
  function open(page) {
    return page.goto('https://example.com/landing');
  },

  async function loginWith({ email, password }, page) {
    await page.fill('#username', user);
    await page.fill('#password', password);
    await page.click('#login-button');
  }
}


const Dashboard = {
  async function verify(page) {
    await expect(page).toHaveURL('https://example.com/dashboard');
  },

  function welcomeMessage(email, page) {
    const message = `Welcome ${email}, good to see you!`;
    return page.locator('.Toastify__toast').filter({ hasText: message })
  }
}

```

### You said objects... by I see no classes


## Conclusion

Abstracting your tests with Page Objects in Playwright is a best practice that simplifies test maintenance, improves readability, and makes your tests more resilient to changes in the UI. By isolating page-specific logic in separate classes, you minimize duplication and ensure that changes in the UI impact only the relevant Page Objects, rather than every test.

Playwright, with its flexibility and powerful APIs, pairs perfectly with the Page Object Model to create robust, scalable, and maintainable test suites. This approach not only makes your tests easier to read and manage but also future-proofs them against inevitable changes to the application.

Now, next time your web app changes, your tests won't break—just update the abstraction layer, and you're good to go!
