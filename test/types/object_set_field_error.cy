type S:
    var a float

var o = [S a: 123]
o.a = []

--cytest: error
--CompileError: Expected type `float`, got `List`.
--
--main:5:7:
--o.a = []
--      ^
--