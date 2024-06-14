package main

import (
	"bufio"
	"fmt"
	"os/exec"
)

func handlePIV(uid string, simulate bool) {
	fmt.Println(Green, "\nHandling PIV card...", Reset)
	if simulate {
		fmt.Println(Green, "\nSimulating the PIV card on your Proxmark3:", Reset)
		command := fmt.Sprintf("hf 14a sim -t 3 --uid %s", uid)
		fmt.Println(Yellow, "\nExecuting command:", command, Reset)
		fmt.Println(Yellow, "", Reset)
		cmd := exec.Command("pm3", "-c", command)

		stdout, err := cmd.StdoutPipe()
		if err != nil {
			fmt.Println(Red, "Error creating StdoutPipe:", err, Reset)
			return
		}
		stderr, err := cmd.StderrPipe()
		if err != nil {
			fmt.Println(Red, "Error creating StderrPipe:", err, Reset)
			return
		}

		if err := cmd.Start(); err != nil {
			fmt.Println(Red, "Error starting command:", err, Reset)
			return
		}

		go func() {
			scanner := bufio.NewScanner(stdout)
			for scanner.Scan() {
				fmt.Println(scanner.Text())
			}
		}()

		go func() {
			scanner := bufio.NewScanner(stderr)
			for scanner.Scan() {
				fmt.Println(scanner.Text())
			}
		}()

		if err := cmd.Wait(); err != nil {
			fmt.Println(Red, "\nCommand finished with error:", err, Reset)
		} else {
			fmt.Println(Green, "\nSimulation completed", Reset)
		}
	} else {
		fmt.Println(Green, "\nTo simulate this PIV card on your Proxmark3 run:\n", Reset)
		fmt.Println(Yellow, fmt.Sprintf("hf 14a sim -t 3 --uid %s", uid), Reset)
	}
}

func handleMIFARE(uid string, simulate bool) {
	fmt.Println(Green, "\nHandling MIFARE card...", Reset)
	if simulate {
		fmt.Println(Green, "\nSimulating the MIFARE card on your Proxmark3:", Reset)
		command := fmt.Sprintf("hf 14a sim -t 1 --uid %s", uid)
		fmt.Println(Yellow, "\nExecuting command:", command, Reset)
		fmt.Println(Yellow, "", Reset)
		cmd := exec.Command("pm3", "-c", command)

		stdout, err := cmd.StdoutPipe()
		if err != nil {
			fmt.Println(Red, "Error creating StdoutPipe:", err, Reset)
			return
		}
		stderr, err := cmd.StderrPipe()
		if err != nil {
			fmt.Println(Red, "Error creating StderrPipe:", err, Reset)
			return
		}

		if err := cmd.Start(); err != nil {
			fmt.Println(Red, "Error starting command:", err, Reset)
			return
		}

		go func() {
			scanner := bufio.NewScanner(stdout)
			for scanner.Scan() {
				fmt.Println(scanner.Text())
			}
		}()

		go func() {
			scanner := bufio.NewScanner(stderr)
			for scanner.Scan() {
				fmt.Println(scanner.Text())
			}
		}()

		if err := cmd.Wait(); err != nil {
			fmt.Println(Red, "Command finished with error:", err, Reset)
		} else {
			fmt.Println(Green, "\nSimulation complete.", Reset)
		}
	} else {
		fmt.Println(Green, "\nTo simulate this MIFARE card on your Proxmark3 run:\n", Reset)
		fmt.Println(Yellow, fmt.Sprintf("hf 14a sim -t 1 --uid %s", uid), Reset)
	}
}
