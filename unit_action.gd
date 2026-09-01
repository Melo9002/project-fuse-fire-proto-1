class_name UnitAction
extends RefCounted

## Abstract base class for all tactical unit commands (Command Pattern).
## Enforces a uniform contract for validation and transaction execution.

## Virtual method: Checks if the action's preconditions are met.
func is_valid() -> bool:
	push_error("UnitAction.is_valid() is a virtual method and must be overridden in child classes.")
	return false

## Virtual method: Commits state mutations and executes the action.
func execute() -> bool:
	push_error("UnitAction.execute() is a virtual method and must be overridden in child classes.")
	return false
