# red-green

Red-Green is a TDD (Test Driven Development) testing tool.

It continuously monitors a set of files for changes.  When a file or
set of files change a part of the script is run to check their status.
This could be unit tests, or a lint type program, or a combination.

A short feedback loop while doing TDD gives the advantage of quick
understanding of the effect of changes as you make them.  In order to
make this more effective, there must be minimal lag time rom the time
the file changes to the display of the results.  A few things have
been done in an attempt to increase the speed of the feedback loop:

* only the files changed are tested.
* the web browser is using long polling to keep a connection open to the server until it responds with the latest update.
* ajax is used to update web elements rather than reloading the page.

To trigger a new test, all is needed is for a file to be modified,
added, or removed.  This will trigger a retest of the files.  Tests
are run and results displayed.  Usually in a fraction of a second.

This is still a bit rudamentary in its current form.  Contributions
are welcome.