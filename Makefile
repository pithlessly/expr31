compute_exprs: compute_exprs.zig
	zig build-exe -OReleaseFast $<

.PHONY: clean
clean:
	rm compute_exprs
