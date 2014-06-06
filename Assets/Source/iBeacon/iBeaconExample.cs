using UnityEngine;
using System.Collections;

public class iBeaconExample : MonoBehaviour {

	// Use this for initialization
	void Start () {
		iBeacon.Init();
		iBeacon.Transmit();
	}
	
	// Update is called once per frame
	void Update () {

	}
}
