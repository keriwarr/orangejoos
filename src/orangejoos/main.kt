package orangejoos

fun main(args : Array<String>) {
    if (args.size != 1) {
        println("Please provide a file to parse")
        return
    }
    println("Parsing ${args[0]}!")
}