function leak()
	for i=1:100000
		t = Task(eval(:(function() produce() end)))
		consume(t)
		try
		  Base.throwto(t, nothing)
		end
	end
	gc()
end
