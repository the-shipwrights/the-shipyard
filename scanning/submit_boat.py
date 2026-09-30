import requests
from boat import Boat, Piece


def submit_scanned_boat(boat: Boat, server_url: str = "http://localhost:8000") -> str:
    """Send a scanned Boat instance to the backend and return the generated 4-letter ID."""
    endpoint = f"{server_url.rstrip('/')}/api/boats"
    
    # BoatPayload expects a list of pieces matching PiecePayload
    payload = {
        "pieces": [piece.to_dict() for piece in boat.pieces],
        "edges": [edge.to_dict() for edge in boat.edges]
    }

    response = requests.post(endpoint, json=payload, timeout=5.0)
    response.raise_for_status()

    # The API returns the serialized boat document containing the assigned ID
    data = response.json()
    return data["id"]






def test_boat_submission():
    # 1. Simulate a boat detected by the vision system
    # (Matches piece IDs: 0=hull_front, 1=hull_middle, 2=hull_back, 3=cabin)
    scanned_boat = Boat(
        pieces=[
            Piece(0, 0,   0,   0),    # left/end hull
            Piece(1, 1, 150,   0),    # middle hull
            Piece(6, 1, 250,   0),    # middle hull
            Piece(2, 2, 350,   0),    # right/end hull
            Piece(3, 3, 150, 100),    # cabin
            Piece(7, 5, 250, 100),    # cabin
            Piece(5, 6, 195, 200),    # flag on cabin
        ]
    )

    # 2. Optional local pre-validation using Boat's validation logic
    validation_errors = scanned_boat.validate()
    if validation_errors:
        print(f"Validation failed before sending: {validation_errors}")
        return

    # 3. Post to the FastAPI backend
    try:
        boat_id = submit_scanned_boat(scanned_boat, server_url="http://localhost:8000")
        print(f"Success! Boat registered with ID: {boat_id}")
        print(f"Participant customizer link: http://localhost:5173/boat/{boat_id}")
    except requests.exceptions.HTTPError as err:
        print(f"Server rejected boat payload: {err.response.status_code} - {err.response.text}")
    except requests.exceptions.ConnectionError:
        print("Could not connect to FastAPI server. Ensure main.py is running.")


if __name__ == "__main__":
    test_boat_submission()