using UnityEngine;
using System.Collections;
using System.Collections.Generic;

public class iBeaconReceiverExample : MonoBehaviour {
	private Vector2 scrolldistance;
	private List<Beacon> mybeacons = new List<Beacon>();
	private bool scanning = true;
	// Use this for initialization
	void Start () {
		iBeaconReceiver.BeaconRangeChangedEvent += OnBeaconRangeChanged;
		iBeaconReceiver.BeaconArrivedEvent += OnBeaconArrived;
		iBeaconReceiver.BeaconOutOfRangeEvent += OnBeaconOutOfRange;
		iBeaconReceiver.Init();
		Debug.Log ("Listening for beacons");
	}
	
	void OnDestroy() {
		iBeaconReceiver.BeaconRangeChangedEvent -= OnBeaconRangeChanged;
		iBeaconReceiver.BeaconArrivedEvent -= OnBeaconArrived;
		iBeaconReceiver.BeaconOutOfRangeEvent -= OnBeaconOutOfRange;
	}
	// Update is called once per frame
	void Update () {
	
	}

	private void OnBeaconArrived(Beacon beacon) {
		Debug.Log ("Beacon arrived: "+beacon.ToString());
	}

	private void OnBeaconOutOfRange(Beacon beacon) {
		Debug.Log ("Beacon out of range: "+beacon.ToString());
	}

	private void OnBeaconRangeChanged(List<Beacon> beacons) {
		mybeacons = beacons;
	}
	
	void OnGUI() {
		GUIStyle labelStyle = GUI.skin.GetStyle("Label");
#if UNITY_ANDROID
		labelStyle.fontSize = 40;
#elif UNITY_IOS
		labelStyle.fontSize = 25;
#endif
		float currenty = 10;
		float labelHeight = labelStyle.CalcHeight(new GUIContent("IBeacons"), Screen.width-20);
		GUI.Label(new Rect(currenty,10,Screen.width-20,labelHeight),"IBeacons");
		
		currenty += labelHeight;
		scrolldistance = GUI.BeginScrollView(new Rect(10,currenty,Screen.width -20, Screen.height - currenty - 10),scrolldistance,new Rect(0,0,Screen.width - 20,mybeacons.Count*100));
		GUILayout.BeginVertical("box",GUILayout.Width(Screen.width-20),GUILayout.Height(50));
		foreach (Beacon b in mybeacons) {
			GUILayout.Label("UUID: "+b.UUID);
			GUILayout.Label("Major: "+b.major);
			GUILayout.Label("Minor: "+b.minor);
			GUILayout.Label("Range: "+b.range.ToString());
		}
		GUILayout.EndVertical();
		GUI.EndScrollView();
	}
}
