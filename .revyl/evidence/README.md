# Revyl run evidence

## add-moment-coffee-with-sam on the iOS skeleton

| | |
| --- | --- |
| Build | `revyl build --platform ios` with `.revyl/config.yaml`, build version `a9eee349-cd68-4743-a325-d8c3e1ff9ef0`, from main plus `capy/ios-skeleton` at 1c06721 |
| Device | iPhone 17 Pro Max, iOS 27.0 |
| Run | [3c40d653](https://app.revyl.ai/tests/report?taskId=3c40d653-2478-4efc-add6-d79a52aa32d3), passed both steps in 64.8 s |
| What the agent did | Tapped the pencil, typed "Revyl" as the name and "Coffee with Sam" as the moment, and tapped post |
| What it checked | The top row reads "Coffee with Sam", "Revyl · now" |

![Coffee with Sam by Revyl at the top of the list](coffee-with-sam-pass.png)

## Earlier runs

- [445753a4](https://app.revyl.ai/tests/report?taskId=445753a4-d6d2-40e2-b4cb-be24144d0de7), PR #2's moments app, build `d0ac52d6`: passed after a real tap, type and post (130 s).
- [ed390d64](https://app.revyl.ai/tests/report?taskId=ed390d64-d4ab-4800-b00d-4b15a6571b0c), skeleton build: reported a pass but performed no actions. The "Coffee with Sam" row from the first run was still in the shared Convex list, so the agent treated the add step as done. This run doesn't count. After it, the test was rewritten to require a new row by "Revyl" posted just now.
