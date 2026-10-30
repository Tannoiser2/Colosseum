extends SceneTree
## Compila tutti gli script (controllo veloce degli errori).
func _init() -> void:
	for d in ["res://scripts/core", "res://scripts/data", "res://scripts/net", "res://scripts/ui"]:
		var da := DirAccess.open(d)
		if da == null:
			continue
		for f in da.get_files():
			if f.ends_with(".gd"):
				var s = load(d + "/" + f)
				if s == null:
					print("ERRORE: ", f)
	print("controllo finito")
	quit()
