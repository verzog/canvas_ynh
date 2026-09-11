**Before installing, please note:**

* **Dedicated domain required.** Canvas must run at the root of its own domain (e.g. `canvas.example.org`); it cannot be installed under a path such as `example.org/canvas`.
* **Hardware.** Plan for at least **4 GB RAM** for installation (the webpack asset build is memory-hungry) and **2 GB+** for day-to-day running, plus ~12 GB of disk.
* **Install time is long.** The install builds Ruby from source and compiles all frontend assets. Expect this to take a while (tens of minutes) depending on the server.
* **Email.** Outgoing mail is wired to the local YunoHost mail server. Configure your domain's mail (SPF/DKIM) so Canvas notifications are delivered.
