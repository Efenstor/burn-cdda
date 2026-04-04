# burn-cdda.sh

**WARNING:** *cdrdao v1.2.5* has the CD-TEXT writing functionality broken (you will literally get broken words in your CD-TEXT), *v1.2.4* does not seem to write CD-TEXT at all. If your distro (e.g. Debian trixie) uses v1.2.5 or v1.2.4 please manually download and install v1.2.6 or later instead (e.g. use deb package from [Debian forky](https://packages.debian.org/forky/amd64/cdrdao/download)).

Requirements
--

* cdrdao >=1.2.6

Description
--

This script burns separate .wav tracks from a chosen directory (alphabetically sorted) using *cdrdao* onto an Audio CD with optional CD-TEXT. For CD-TEXT information should be defined in a plain-text file which looks like this:

```
  Performer Name
  Album Title

  Track Name
  Track Name
```

By default it burns using the lowest possible speed. There are some options at the beginning of the script which can be edited.
