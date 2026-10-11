import onnx

model = onnx.load("android/app/src/main/assets/vekol/model.onnx")

print("=== INPUTS ===")
for x in model.graph.input:
    print(x.name)

print("=== OUTPUTS ===")
for x in model.graph.output:
    print(x.name)
