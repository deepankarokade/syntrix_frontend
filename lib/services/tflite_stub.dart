class Interpreter {
  static Future<Interpreter> fromAsset(String assetName, {dynamic options}) async {
    return Interpreter();
  }
  void close() {}
  void run(Object input, Object output) {}
}

class InterpreterOptions {}
