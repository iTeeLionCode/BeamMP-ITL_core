## ITLcore

Server-side BeamMP plugin for management

## Console commands:

| Description | Syntax |
| ------ | ------ |
| Show all commands | commands |
| Manual reload players cache | reloadplayers |
| Show current players cache | playerscache |
| Kick and ban player | ban nick "reason" duration |
| Disallow chat for player | mute nick "reason" duration |

## Chat commands:

| Description | Syntax |
| ------ | ------ |
| Show current player nickname | whoami |
| Manual reload players cache | reloadplayers |
| Show online players | players |
| Show online players for admins with additional info | aplayers |
| Kick player from server | kick nick "reason" |
| Kick and ban player | ban nick "reason" duration |
| Disallow chat for player | mute nick "reason" duration |

## Chat commands durations syntax

- 33m - 33 minutes
- 23h - 23 hours
- 54d - 54 days

Example 1 hour and 5 minutes: 1h5m

## Plugin installation

- Drop Config and Resources folder in to root folder of your server
- Import db.sql in to your MySQL server
- Copy config example "Config/mysql.json.example" to the same place with name "mysql.json" and cofigure it
- Copy config example "Resources/Server/ITL_core/config/main.json.example" to the same place with name "main.json" and cofigure it

## Plugin update

- Drop Config and Resources folder in to root folder of your server
- Add new missing config rows from examples (if update contains new rows)
- You need to manual update DB configuration from new db.sql (That's temporary thing, i'm working on fix)
