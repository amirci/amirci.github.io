---
layout: post
title:  "Refactoring multiple updates with reduce"
date:   2024-04-02 00:16:58 -0700
categories: refactoring
---

## The problem

The refactoring story today is about a UI editor for a table of _Students_ that lets a user
add, rename and remove columns.

To do so it generates a series of changes than have to be applied and saved to the database.

We will skip the _React_ portion of the code and we will focus on how to model the changes and the update process.

```ts
import { pipe } from 'fp-ts/function';
import * as A from 'fp-ts/Array';

const changeExistingStudentsTable = (tableInfo: any, columnChanges: any, idx: number) => {
  const isChange = (columnChange: any): boolean =>
    !(
      !columnChange.mergedCol &&
      !columnChange.deleted &&
      columnChange.original === columnChange.current
    );

  const mergeCol = (sourceCol: string, targetCol: string, needDeleteSourceCol: boolean) => (d: any) => {
      // if create new col and merge at the same time,
      // no need to remove the new col as it does not exist; only fill merged col with null
      if (!needDeleteSourceCol) {
        d[idx].values = d[idx].values.map(v => {
          v[targetCol] = null;
          return v;
        });
      } else {
        d[idx].columns = A.filter(e => e !== sourceCol)(d[idx].columns);
        d[idx].values = d[idx].values.map(v => {
          v[targetCol] = v[sourceCol];
          v[sourceCol] = undefined;
          return v;
        });
      }
      return d;
    };

  const deleteCol = (deletedCol: string, isExist: boolean) => (d: any) => {
    // if {current : 'new column', deleted: true} -> add and immediately delete, no need to delete
    // if {current : 'new column', original: 'exist name', deleted: true}  -> add 'new column' save, then change name and delete --> delete 'new column'
    if (isExist) {
      // todo:
      d[idx].columns = A.filter(e => e !== deletedCol)(d[idx].columns);
      d[idx].values = d[idx].values.map(v => {
        v[deletedCol] = undefined;
        return v;
      });
    }
    return d;
  };

  const addCol = (newCol: string) => (d: any) => {
    d[idx].columns.push(newCol);
    d[idx].values = d[idx].values.map(v => {
      // todo: how to refactor
      v[newCol] = undefined;
      return v;
    });
    return d;
  };

  const renameCol = (old_name: string, new_name: string) => (d: any) => {
    d[idx].columns = pipe(
      d[idx].columns,
      A.filter(e => e !== old_name),
      cols => [...cols, new_name],
    );
    d[idx].values = d[idx].values.map(v => {
      v[new_name] = v[old_name];
      return v;
    });
    return d;
  };

  const getChangeFunc = (columnChange: any): any => {
    if (columnChange.mergedCol) {
      return mergeCol(
        columnChange.current,
        columnChange.mergedCol,
        Boolean(columnChange.original),
      );
    } else if (columnChange.deleted) {
      return deleteCol(columnChange.original, Boolean(columnChange.original));
    } else if (!columnChange.original) {
      return addCol(columnChange.current);
    } else if (columnChange.original !== columnChange.current) {
      return renameCol(columnChange.original, columnChange.current);
    }
  };
  const modifyData = (cur: any, op: any) => op(cur);
  return pipe(
    columnChanges,
    A.filter(isChange),
    A.map(getChangeFunc),
    A.reduce(tableInfo, modifyData),
  );
};

```

## Identifying candidates for refactoring

I noticed first (before reading the body of the function) that the _signature_ uses the type `any` for each of the arguments.

Perhaps we could _narrow_ the types to make it more specific to the actual possible values. Plus one for modeling with types!

Looking at how the arguments are used in the main function, it looks like we could create a `Student` type that can have _properties_ and then a `StudentTable` that contains the columns and a collection of values (rows).


```ts
type Student = Record<string, any>;

type ColumnName = string;

type StudentTable {
  columns: ColumnName[];
  values: readonly Student[];
}

// For example a table that has First Name, Last Name, Age and Eye Color would look like:

const table: StudentTable = {
  columns: ["FirstName", "LastName", "Age", "EyeColor"],
  values: [
    {FirstName: "Juan", LastName: "Rodriguez", Age: 10, EyeColor: "Green"},
    {FirstName: "Rose", LastName: "Bidai", Age: 11, EyeColor: "Brown"}
  ]
}

```

The changes could also be captured in a type, something like:

```ts
type ColumnChange = {
  deleted?: string;
  original?: string;
  current?: string;
  mergedCol?: string;
};
```

However, having all fields optional hints that some combinations are probably are invalid. We can try to represent the changes in
a way that captures the intention behind each change and makes the states that cannot be valid impossible to build.


```ts

type ColumnName = string;
// Possible values for the type of change
type ChangeType = 'remove' | 'add' | 'rename' | 'delete' | 'none';
// A discrimination must have a `type`
type ChangeTypeDiscriminator = { type: ChangeType };

// Each kind of change, they all must have a `ChangeTypeDiscriminator`
type RemoveColumn = { type: 'remove'; target: ColumnName } & ChangeTypeDiscriminator;
type AddColumn = { type: 'add'; target: ColumnName } & ChangeTypeDiscriminator;
type RenameColumn = { type: 'rename'; target: ColumnName; source: ColumnName } & ChangeTypeDiscriminator;
type DeleteColumn = { type: 'delete'; target: ColumnName } & ChangeTypeDiscriminator;
type NoChange = { type: 'none' };

// Type that contains all the changes
type ColumnChange = RemoveColumn | AddColumn | RenameColumn | DeleteColumn | NoChange;

```




```ts
type UpdateFn = (tables: StudentTable[], idx: number) => StudentTable[];

type ChangeMapFn = (change: ColumnChange) => UpdateFn;
```
## Implementing the changes

```ts
const applyChangesToTable = (tableInfo: TableInfo[], changes: readonly ColumnChange[], idx: number) => {
  return pipe(
    changes,
    ROA.filter(isChange),
    ROA.map(changeToUpdateFn),
    ROA.reduce(tableInfo, (table: TableInfo[], updateFn: UpdateFn) => updateFn(table, idx))
  );
};

```

