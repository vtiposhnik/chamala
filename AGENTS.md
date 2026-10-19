# Object Rain development

Work within the existing Godot project and preserve stable gameplay unless the
requested iteration explicitly changes it. Use Godot 4.x GDScript and the
Compatibility renderer; no plugins are required.

For every development iteration, update both `docs/DEVELOPMENT_LOG.md` and
`docs/CURRENT_STATE.md` before finishing. Record verified changes, technical
decisions, bugs fixed, limitations and suggested next steps. Keep controls and
configuration values current. Do not invent historical details or implement
suggested next steps without authorization.

Run the relevant existing Godot tests and add meaningful regression coverage for
changed behavior. See README.md for commands. Keep generated `.godot/` and build
outputs out of version control.

After each completed change, run the relevant checks, commit the changes and push
them to the repository. The user has authorized this as the default workflow;
do not wait for a separate push request. Use normal pushes, never force-push.
