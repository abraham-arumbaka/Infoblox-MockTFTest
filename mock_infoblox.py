from flask import Flask, request, jsonify
import ipaddress, uuid

app = Flask(__name__)
allocated = {}  # ref -> cidr
ext_attrs = {}  # name -> EA definition dict

@app.route("/wapi/v2.5/extensibleattributedef", methods=["GET"])
def list_ext_attrs():
    name = request.args.get("name")
    if name:
        ea = ext_attrs.get(name)
        if ea:
            return jsonify([ea])
        return jsonify([])
    return jsonify(list(ext_attrs.values()))

@app.route("/wapi/v2.5/extensibleattributedef", methods=["POST"])
def create_ext_attr():
    data = request.json or {}
    name = data.get("name", "")
    ref = f"extensibleattributedef/{uuid.uuid4()}:{name}"
    ea = {
        "_ref": ref,
        "name": name,
        "type": data.get("type", "STRING"),
        "flags": data.get("flags", ""),
        "comment": data.get("comment", ""),
        "list_values": data.get("list_values", []),
        "allowed_object_types": data.get("allowed_object_types", []),
    }
    ext_attrs[name] = ea
    return jsonify(ref), 201

@app.route("/wapi/v2.5/networkcontainer", methods=["GET"])
def list_containers():
    return jsonify([{"_ref": "networkcontainer/ZG5z:10.0.0.0/8/default", "network": "10.0.0.0/8"}])

def allocate_next_network(prefix_len):
    """Return the next available subnet string from 10.0.0.0/8."""
    base = ipaddress.ip_network("10.0.0.0/8")
    used = {ipaddress.ip_network(v) for v in allocated.values()}
    for subnet in base.subnets(new_prefix=prefix_len):
        if subnet not in used:
            cidr = str(subnet)
            allocated[str(uuid.uuid4())] = cidr
            return cidr
    return None

@app.route("/wapi/v2.5/networkcontainer/<path:ref>", methods=["POST"])
def next_available_network_on_ref(ref):
    func = request.args.get("_function")
    if func == "next_available_network":
        body = request.json or {}
        num = int(body.get("num", 1))
        prefix_len = int(body.get("cidr", 24))
        networks = []
        for _ in range(num):
            cidr = allocate_next_network(prefix_len)
            if cidr:
                networks.append(cidr)
        return jsonify({"networks": networks})
    return jsonify({}), 400

@app.route("/wapi/v2.5/networkcontainer", methods=["POST"])
def next_available_network():
    func = request.args.get("_function")
    if func == "next_available_network":
        body = request.json or {}
        num = int(body.get("num", 1))
        prefix_len = int(body.get("cidr", 24))
        networks = []
        for _ in range(num):
            cidr = allocate_next_network(prefix_len)
            if cidr:
                networks.append(cidr)
        return jsonify({"networks": networks})
    return jsonify({}), 400

@app.route("/wapi/v2.5/network", methods=["POST"])
def create_network():
    data = request.json or {}
    network_val = data.get("network", "")

    # Handle func:nextavailablenetwork:<parent_cidr>,<netview>,<prefix_len>
    if network_val.startswith("func:nextavailablenetwork:"):
        args = network_val.split(":", 2)[2]          # "10.0.0.0/8,default,24"
        parts = args.split(",")
        prefix_len = int(parts[2]) if len(parts) >= 3 else 24
        cidr = allocate_next_network(prefix_len)
        if cidr is None:
            return jsonify({"text": "No available networks"}), 500
    else:
        cidr = network_val

    netview = data.get("network_view", "default")
    ref = f"network/ZG5z:{cidr}/{netview}"
    allocated[ref] = cidr
    return jsonify(ref), 201

@app.route("/wapi/v2.5/network/<path:ref>", methods=["GET", "PUT", "DELETE"])
def network_by_ref(ref):
    # Extract CIDR from the ref regardless of the base64 portion.
    # Ref format: network/<base64>:<cidr>/<network_view>
    # e.g. network/bmV0d29yay8...:10.0.0.0/24/default
    cidr = None
    full_ref = f"network/{ref}"
    if ":" in ref:
        # everything after the last colon up to (but not including) the trailing /default
        after_colon = ref.split(":")[-1]          # e.g. "10.0.0.0/24/default"
        cidr = "/".join(after_colon.split("/")[:2])  # e.g. "10.0.0.0/24"

    if request.method == "GET":
        # Try exact match first, then CIDR match in allocated dict
        stored = allocated.get(full_ref)
        if stored is None and cidr:
            for k, v in allocated.items():
                if v == cidr:
                    stored = v
                    full_ref = k
                    break
        # If not in allocated but CIDR is parseable, synthesise a response
        # (covers resources tracked in tfstate from a prior apply)
        if stored is None and cidr:
            allocated[full_ref] = cidr
            stored = cidr
        if stored is None:
            return jsonify({"text": "Object not found"}), 404
        return jsonify({
            "_ref": full_ref,
            "network": stored,
            "network_view": "default",
            "comment": "",
            "extattrs": {},
        })

    elif request.method == "PUT":
        if full_ref not in allocated and cidr:
            allocated[full_ref] = cidr
        return jsonify(full_ref)

    elif request.method == "DELETE":
        allocated.pop(full_ref, None)
        return jsonify(full_ref)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8443, ssl_context="adhoc")  # pip install pyopenssl