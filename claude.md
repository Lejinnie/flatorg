# FlatOrg

FlatOrg is a app made with react native or flutter. It is made to schedule tasks within a co-living area.

## Tech stack

Frontend: **Flutter**
- Cross-platform (iOS + Android)
- Better UI/UX out of the box
- Good Firebase integration
- React Native considered but Flutter preferred for aesthetics; React's wider ecosystem is a minor tradeoff

Backend: Firebase (Java)?

## Functionality

### Core Function

We assume there are 9 tasks and 9 people. The Tasks are grouped and also have a sequential ordering.

Toilet-> Kitchen -> Recycling -> Shower -> Floor(A) -> Washing rags -> Bathroom -> Floor(B) -> Shopping

Our tasks are divided into three difficulties, hard (3), medium(2) and easy(1). Each of the groups have one task inside.

- Level 3: Toilet, Shower, Bathroom
- Level 2: Floor(A), Floor(B), Kitchen
- Level 1: Recycling, Washing Rags, Shopping & report to @Livit

We want to reward those that do a task by assigning them a task of lower difficulty and those who don’t with a task of higher difficulty. We call those who did their task Green Person, and those who didnt Red Person.(If they are on vacation which is a Blue Person, this is an exception that we go into later.) To implement this, we have the following list which we execute sequentially.

1. people who are on vacation will take up all the easy tasks.
    1. The exact ordering of the people in vacation is not important. But we should try to give those who had a higher task to do, a higher task.
2. people who have done their task should get a less difficult task (unless their previous one was the easiest task, in that case, they can be assigned anywhere)
    1. We start assigning people starting from the highest to lowest difficulty.
    2. If the next task is not assigned, this is their task for next week. 
    3. If already assigned to Green/Blue person, jump over.
3. people who haven’t done their task get a worse task. (if level 3 they stay at level 3) We prioritize filing up the difficulty levels rather than following the order of people.
    1. We start assigning people starting from the highest to lowest difficulty. (to be discussed)
    2. if the previous task is not assigned, this is the new task for the week.
    3. If the previous task is taken, take another from the same difficulty. If above difficulty is full, we repeat the task next week. (might cause conflicts, to be discussed)

A few reasoning points:

<aside>
💡

The reason why we assign Green People first, is because we have to guarantee that they get a easier task. If Red People start first, then they might take away the next good task they might've gotten, and since the tasks are circular, they might move to level 3 from task 2. 

Additionally, the red people might take up the top 3 hardest tasks for weeks fi we assign them first since they are not likely to do them. If we do green people first, we have a higher chance that they will be done.

</aside>

### Switching Tasks

People can switch tasks 3 times per semester. (3 Token)

They can switch to a blue task, or with another person if they agree to it. They revert back to their original schedule after the week of doing stuff. It also depends if they did their task or not.

### Vacation people (blue)

People can mark themselves as being on vacation. In that case, follow the rules above.

They are back from vacation when they do a task.

> do we have to recompute the week if they are not here for a week? Or do we just mark them blue and assign them to a lower task next week?
> 

### Notifications

- Saturday + Sunday each once.
- 1h before deadline (sunday 23:59 is deadline)
- When they have not done their task, show them a notification that they should mark themselves on vacation since they mightve forgot. Do this only on vacation times.
    - Refer to https://ethz.ch/staffnet/de/news-und-veranstaltungen/akademischer-kalender.html. Times outside of Prüfungssession & Begin * end of semester.
    - or just do probabilitic notification.
- a notification that a task has been done.

## Further Functionality:

### Shopping list

pretty simple, just a shopping list an another tab

Every person in the flat can add/remove things to the shopping list.

It suffices as a simple text.

user can mark it as done/bought. They will move down the list to a secondary list where it will be grayed out but not yet deleted.

The bought items will be deleted after 6h.

### Complaint List

This is a list of complaints that we have to livit. Also another tab.

When adding it, peopel need to have a title and a description of the complaint.

after adding it it appears on a list.

The user can select (all of them with a button) or select a few that they want and then there will be a button for them to click with will be a mail button which redirects them to their email directed to studentvillage@ch.issworld.com. 

If possible, it would be great to add some boilerplate code.

To avoid spamming, we enable the send button once a week, reset on sunday after 23:59.

## UI/UX

![image](./wireframe.png)

## Implementation Details

Probably best to implement this with a state machine + events & handlers.

### Standards

insert coding practices

### Task class

Each task would be a state machine with attributes on it:

- name
- description
- to be completed date
- person assigned to it
- state [completed, pending, not done]

<aside>
💡

State description:

**Completed:** means that the task is done. Holds until enter_grace_period(), should also stay in this state.

**Pending:** not done yet. Holds until deadline, then becomes NotDone after enter grace period

**Not Done:** only holds right after deadline and until grace period ends (1h for now, might change). changed by reset_for_new_week.

</aside>

and methods such as

**enter_grace_period();**

- probably more or less ui/ux thing. Updates color from yellow to red. Ah no it also does pending → Not Done.

**reset_for_new_week();**

- does most of the assignments following the above rules.

**completed_task();**

- sets to true. also sets person to being not vacation if they are.

**request_change_task();**

- requests another task to change assignee. To do this, we can shoot an event to them (or call this method i guess but event seems more proper)
- they then send a notification or have an extra field on top of the tasks where they can accept or decline. this is ofc sent back to the original change task shit, who sets the pending request_changetask to false and displays it as such in the notification tile.

 

### Person class

- name
- login details? do I need this? it should only be for my own flat right?
- how do I identify whoever is here has the rights? (or does everybody have rights to everything?)
- on_vacation = true/false

methods:

on_vacation(); - sets on vacation

some methods to verify they are the right person?

### Login??

---

## Open Discussion Points

### Tech Stack

1. ~~**Frontend: React Native vs Flutter**~~ → **Flutter** chosen. Better aesthetics, good Firebase integration.
2. **Backend: Firebase specifics** — "Firebase (Java)?" is ambiguous. Firebase is a BaaS. Do you need a custom backend at all, or can Firestore + Cloud Functions handle everything?
3. **Authentication strategy** — the doc ends with "Login??" and asks "does everybody have rights to everything?" — this needs a decision
4. **Push notifications** — which service handles this? Firebase Cloud Messaging (FCM)? How does it integrate with the chosen frontend?
5. **State management** — what library/pattern to use on the frontend (Redux, Zustand, Riverpod, BLoC, etc.)

### Functional / Design Gaps

6. **Vacation week recompute** — do we recompute the week if someone isn't here, or just mark them blue and assign lower next week?
7. **Red person conflict resolution** — "If previous task is taken, repeat next week" — what happens if this cascades?
8. **Task switch revert logic** — how exactly does the token-based swap revert if the person did/didn't do the task?
9. **Week reset trigger** — what triggers `reset_for_new_week()`? A cron job? Manual? Deadline passing?
10. **Notification for ETH exam periods** — check the ETH academic calendar or use probabilistic notifications — which approach?