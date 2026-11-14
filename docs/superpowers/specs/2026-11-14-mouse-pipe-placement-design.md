# Mouse Pipe Placement

User-approved controls: P selects water pipes without placing anything; left click
places at the cursor, dragging paints connected cardinal cells without sampling
gaps, Shift+left click/drag removes only water pipes, right click or Escape exits.
T selects the same tool. B and slots 1-4 retain their existing bindings.

This replaces the same-day actor-cell P shortcut. Individual guide rotation is no
longer a player operation; neighboring pieces still join automatically. Pipes
remain free, noncolliding and behind ladders/actors. Placement reach, rock and
inline-pump rules remain enforced; an invalid cell stops the current stroke there
rather than laying disconnected pieces beyond it. Existing pipes are idempotent.
An invalid first click cancels that gesture until a new press. Mouse-up completes
only an unvisited final segment using the last drag operation; releasing Shift
before releasing the mouse cannot recreate a pipe that was just erased.

Use a deterministic grid traversal between cursor samples, inserting a cardinal
step at diagonal crossings. Consume water-tool clicks before room/repair menus
and mining; right-click cancellation must work even over interactable objects.
Clear drag state on release, focus loss, blocked controls and tool changes.
Show a blue valid-cell/pipe preview, red when invalid, and a removal highlight when
Shift is held. No new recipes, save formats or world simulation changes.

Approach: extend the existing IndustryUI mouse tool, rather than add a separate
construction mode or another menu. A click-only alternative was rejected because
it would require one action per cell and fail the requested rapid drawing flow.
